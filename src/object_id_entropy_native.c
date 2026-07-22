#include <moonbit.h>

#include <stdint.h>

#if defined(_WIN32)
#include <stdlib.h>
#else
#include <sys/random.h>
#endif

MOONBIT_FFI_EXPORT int32_t moonbit_bson_secure_random(moonbit_bytes_t buffer) {
  const int32_t length = Moonbit_array_length(buffer);
  if (length <= 0) return 0;
#if defined(_WIN32)
  uint8_t *bytes = (uint8_t *)buffer;
  for (int32_t offset = 0; offset < length; offset += 4) {
    unsigned int word = 0;
    if (rand_s(&word) != 0) return -1;
    int32_t remaining = length - offset;
    int32_t copy = remaining < 4 ? remaining : 4;
    for (int32_t index = 0; index < copy; index++) {
      bytes[offset + index] = (uint8_t)(word >> (index * 8));
    }
  }
  return 0;
#else
  return getentropy((void *)buffer, (size_t)length) == 0 ? 0 : -1;
#endif
}
