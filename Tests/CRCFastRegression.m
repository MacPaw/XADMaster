#import <stdint.h>
#import <stdio.h>

#import "CRC.h"

static int run_crc_check(const uint8_t *buffer, int length, const char *label)
{
    uint32_t slow = XADCalculateCRC(0xFFFFFFFFu, buffer, length, XADCRCTable_edb88320);
    uint32_t fast = XADCalculateCRCFast(0xFFFFFFFFu, buffer, length, XADCRCTable_sliced16_edb88320);

    if (slow != fast) {
        fprintf(stderr, "%s mismatch: slow=0x%08x fast=0x%08x length=%d\n", label, slow, fast, length);
        return 1;
    }

    return 0;
}

int main(void)
{
    uint32_t words[128];
    uint8_t *buffer = (uint8_t *)words;
    int failed = 0;

    // Use deterministic data so the regression is stable across environments.
    for (size_t i = 0; i < (sizeof(words) / sizeof(words[0])); i++) {
        words[i] = (uint32_t)(0x9E3779B9u * (uint32_t)(i + 1u)) ^ (uint32_t)(0xA5A5A5A5u + (uint32_t)i);
    }

    failed |= run_crc_check(buffer, 64, "exact-fast-block");
    failed |= run_crc_check(buffer, 65, "fast-block-plus-tail");
    failed |= run_crc_check(buffer, 127, "multi-block-odd-tail");
    failed |= run_crc_check(buffer, (int)sizeof(words), "full-buffer");

    return failed;
}
