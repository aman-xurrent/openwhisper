#ifndef SAYTYPE_LLAMA_SHIM_H
#define SAYTYPE_LLAMA_SHIM_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct saytype_llm saytype_llm;
typedef void (*saytype_llm_log_callback)(int32_t level, const char * text, void * user_data);

enum {
    SAYTYPE_LLM_ERROR_TEMPLATE = -1,
    SAYTYPE_LLM_ERROR_PROMPT_TOO_LONG = -2,
    SAYTYPE_LLM_ERROR_DECODE = -3,
    SAYTYPE_LLM_ERROR_OUTPUT_TOO_SMALL = -4,
};

enum {
    SAYTYPE_LLM_LOG_LEVEL_ERROR = 4,
};

void saytype_llm_set_log_callback(saytype_llm_log_callback callback, void * user_data);

saytype_llm * saytype_llm_open(const char * model_path, bool use_gpu, uint32_t context_tokens, int32_t threads);
void saytype_llm_close(saytype_llm * llm);

/// Renders a system + user chat prompt with the model's template, decodes it, and generates greedily.
/// Returns the number of UTF-8 bytes written to output (not NUL counted) or a negative error code.
int32_t saytype_llm_complete(
    saytype_llm * llm,
    const char * system_prompt,
    const char * user_prompt,
    int32_t max_output_tokens,
    char * output,
    int32_t output_capacity);

#ifdef __cplusplus
}
#endif

#endif
