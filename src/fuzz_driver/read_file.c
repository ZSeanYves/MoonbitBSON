#include <moonbit.h>

#include <stdio.h>
#include <stdint.h>

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_bson_read_file(moonbit_bytes_t path) {
  FILE *file = fopen((const char *)path, "rb");
  if (file == NULL) return moonbit_empty_int8_array;
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return moonbit_empty_int8_array;
  }
  long size = ftell(file);
  if (size < 0 || size > INT32_MAX) {
    fclose(file);
    return moonbit_empty_int8_array;
  }
  rewind(file);
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)size, 0);
  if (size > 0 && fread((void *)result, 1, (size_t)size, file) != (size_t)size) {
    fclose(file);
    return moonbit_empty_int8_array;
  }
  fclose(file);
  return result;
}
