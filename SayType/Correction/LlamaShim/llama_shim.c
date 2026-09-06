#include "llama_shim.h"

#include <llama/llama.h>
#include <stdlib.h>
#include <string.h>

#define SAYTYPE_LLM_ALL_GPU_LAYERS 999
#define SAYTYPE_LLM_PIECE_BUFFER 256

struct saytype_llm {
    struct llama_model * model;
    struct llama_context * context;
    const struct llama_vocab * vocab;
    struct llama_sampler * sampler;
    char * chat_template;
};

static saytype_llm_log_callback g_log_callback = NULL;
static void * g_log_user_data = NULL;

static void forward_log(enum ggml_log_level level, const char * text, void * user_data) {
    (void)user_data;
    if (g_log_callback != NULL) {
        g_log_callback((int32_t)level, text, g_log_user_data);
    }
}

void saytype_llm_set_log_callback(saytype_llm_log_callback callback, void * user_data) {
    g_log_callback = callback;
    g_log_user_data = user_data;
    llama_log_set(forward_log, NULL);
}

saytype_llm * saytype_llm_open(const char * model_path, bool use_gpu, uint32_t context_tokens, int32_t threads) {
    static bool backend_ready = false;
    if (!backend_ready) {
        llama_backend_init();
        backend_ready = true;
    }

    struct llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = use_gpu ? SAYTYPE_LLM_ALL_GPU_LAYERS : 0;
    struct llama_model * model = llama_model_load_from_file(model_path, model_params);
    if (model == NULL) {
        return NULL;
    }

    struct llama_context_params context_params = llama_context_default_params();
    context_params.n_ctx = context_tokens;
    context_params.n_batch = context_tokens;
    context_params.n_threads = threads;
    context_params.n_threads_batch = threads;
    struct llama_context * context = llama_init_from_model(model, context_params);
    if (context == NULL) {
        llama_model_free(model);
        return NULL;
    }

    const char * chat_template = llama_model_chat_template(model, NULL);
    if (chat_template == NULL) {
        llama_free(context);
        llama_model_free(model);
        return NULL;
    }

    struct llama_sampler * sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_greedy());

    saytype_llm * llm = calloc(1, sizeof(*llm));
    llm->model = model;
    llm->context = context;
    llm->vocab = llama_model_get_vocab(model);
    llm->sampler = sampler;
    llm->chat_template = strdup(chat_template);
    return llm;
}

void saytype_llm_close(saytype_llm * llm) {
    if (llm == NULL) {
        return;
    }
    llama_sampler_free(llm->sampler);
    llama_free(llm->context);
    llama_model_free(llm->model);
    free(llm->chat_template);
    free(llm);
}

static char * render_prompt(saytype_llm * llm, const char * system_prompt, const char * user_prompt) {
    struct llama_chat_message messages[2] = {
        { "system", system_prompt },
        { "user", user_prompt },
    };
    int32_t capacity = (int32_t)(strlen(system_prompt) + strlen(user_prompt)) * 2 + 1024;
    char * buffer = malloc((size_t)capacity);
    int32_t written = llama_chat_apply_template(llm->chat_template, messages, 2, true, buffer, capacity);
    if (written < 0) {
        free(buffer);
        return NULL;
    }
    if (written >= capacity) {
        capacity = written + 1;
        buffer = realloc(buffer, (size_t)capacity);
        written = llama_chat_apply_template(llm->chat_template, messages, 2, true, buffer, capacity);
        if (written < 0 || written >= capacity) {
            free(buffer);
            return NULL;
        }
    }
    buffer[written] = '\0';
    return buffer;
}

static int32_t tokenize(saytype_llm * llm, const char * text, llama_token ** out_tokens) {
    int32_t text_length = (int32_t)strlen(text);
    int32_t capacity = text_length + 16;
    llama_token * tokens = malloc(sizeof(llama_token) * (size_t)capacity);
    int32_t count = llama_tokenize(llm->vocab, text, text_length, tokens, capacity, true, true);
    if (count < 0) {
        capacity = -count;
        tokens = realloc(tokens, sizeof(llama_token) * (size_t)capacity);
        count = llama_tokenize(llm->vocab, text, text_length, tokens, capacity, true, true);
    }
    if (count < 0) {
        free(tokens);
        return count;
    }
    *out_tokens = tokens;
    return count;
}

int32_t saytype_llm_complete(
    saytype_llm * llm,
    const char * system_prompt,
    const char * user_prompt,
    int32_t max_output_tokens,
    char * output,
    int32_t output_capacity) {
    llama_memory_clear(llama_get_memory(llm->context), true);

    char * prompt = render_prompt(llm, system_prompt, user_prompt);
    if (prompt == NULL) {
        return SAYTYPE_LLM_ERROR_TEMPLATE;
    }

    llama_token * tokens = NULL;
    int32_t count = tokenize(llm, prompt, &tokens);
    free(prompt);
    if (count < 0) {
        return SAYTYPE_LLM_ERROR_TEMPLATE;
    }
    if (count + max_output_tokens >= (int32_t)llama_n_ctx(llm->context)) {
        free(tokens);
        return SAYTYPE_LLM_ERROR_PROMPT_TOO_LONG;
    }
    if (llama_decode(llm->context, llama_batch_get_one(tokens, count)) != 0) {
        free(tokens);
        return SAYTYPE_LLM_ERROR_DECODE;
    }
    free(tokens);

    int32_t written = 0;
    char piece[SAYTYPE_LLM_PIECE_BUFFER];
    for (int32_t index = 0; index < max_output_tokens; index++) {
        llama_token token = llama_sampler_sample(llm->sampler, llm->context, -1);
        if (llama_vocab_is_eog(llm->vocab, token)) {
            break;
        }
        int32_t piece_length = llama_token_to_piece(llm->vocab, token, piece, sizeof(piece), 0, true);
        if (piece_length > 0) {
            if (written + piece_length >= output_capacity) {
                return SAYTYPE_LLM_ERROR_OUTPUT_TOO_SMALL;
            }
            memcpy(output + written, piece, (size_t)piece_length);
            written += piece_length;
        }
        if (llama_decode(llm->context, llama_batch_get_one(&token, 1)) != 0) {
            return SAYTYPE_LLM_ERROR_DECODE;
        }
    }
    output[written] = '\0';
    return written;
}
