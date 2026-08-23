// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#include <stdio.h>
#include <string.h>
#include "UniChecksum.h"

static void report(const char *text) {
  const uint8_t *data = (const uint8_t *)text;
  size_t length = strlen(text);
  printf("\"%s\"\n", text);
  printf("  crc32   %08X\n", unichecksum_crc32(data, length));
  printf("  crc64   %016llX\n",
         (unsigned long long)unichecksum_crc64(data, length));
  printf("  adler32 %08X\n", unichecksum_adler32(data, length));
}

int main(void) {
  printf("UniChecksum %s\n", unichecksum_version());
  report("");
  report("a");
  report("abc");
  report("123456789");

  /* Streaming: the same bytes in two pieces give the same checksum. */
  uint32_t state = unichecksum_crc32_init();
  state = unichecksum_crc32_update(state, (const uint8_t *)"12345", 5);
  state = unichecksum_crc32_update(state, (const uint8_t *)"6789", 4);
  printf("streamed crc32(\"123456789\") = %08X\n",
         unichecksum_crc32_final(state));
  return 0;
}
