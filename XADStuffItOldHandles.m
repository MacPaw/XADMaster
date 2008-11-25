#import "XADStuffItOldHandles.h"
#import "Checksums.h"

/*****************************************************************************/

/* Note: compare with LZSS decoding in lharc! */
#define SITLZAH_N       314
#define SITLZAH_T       (2*SITLZAH_N-1)
/*      Huffman table used for first 6 bits of offset:
        #bits   codes
        3       0x000
        4       0x040-0x080
        5       0x100-0x2c0
        6       0x300-0x5c0
        7       0x600-0xbc0
        8       0xc00-0xfc0
*/

static const xadUINT8 SITLZAH_HuffCode[] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
  0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04,
  0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
  0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08,
  0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c,
  0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c,
  0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
  0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
  0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18,
  0x1c, 0x1c, 0x1c, 0x1c, 0x1c, 0x1c, 0x1c, 0x1c,
  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
  0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24,
  0x28, 0x28, 0x28, 0x28, 0x28, 0x28, 0x28, 0x28,
  0x2c, 0x2c, 0x2c, 0x2c, 0x2c, 0x2c, 0x2c, 0x2c,
  0x30, 0x30, 0x30, 0x30, 0x34, 0x34, 0x34, 0x34,
  0x38, 0x38, 0x38, 0x38, 0x3c, 0x3c, 0x3c, 0x3c,
  0x40, 0x40, 0x40, 0x40, 0x44, 0x44, 0x44, 0x44,
  0x48, 0x48, 0x48, 0x48, 0x4c, 0x4c, 0x4c, 0x4c,
  0x50, 0x50, 0x50, 0x50, 0x54, 0x54, 0x54, 0x54,
  0x58, 0x58, 0x58, 0x58, 0x5c, 0x5c, 0x5c, 0x5c,
  0x60, 0x60, 0x64, 0x64, 0x68, 0x68, 0x6c, 0x6c,
  0x70, 0x70, 0x74, 0x74, 0x78, 0x78, 0x7c, 0x7c,
  0x80, 0x80, 0x84, 0x84, 0x88, 0x88, 0x8c, 0x8c,
  0x90, 0x90, 0x94, 0x94, 0x98, 0x98, 0x9c, 0x9c,
  0xa0, 0xa0, 0xa4, 0xa4, 0xa8, 0xa8, 0xac, 0xac,
  0xb0, 0xb0, 0xb4, 0xb4, 0xb8, 0xb8, 0xbc, 0xbc,
  0xc0, 0xc4, 0xc8, 0xcc, 0xd0, 0xd4, 0xd8, 0xdc,
  0xe0, 0xe4, 0xe8, 0xec, 0xf0, 0xf4, 0xf8, 0xfc};

static const xadUINT8 SITLZAH_HuffLength[] = {
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8};

struct SITLZAHData {
  xadUINT8 buf[4096];
  xadUINT32 Frequ[1000];
  xadUINT32 ForwTree[1000];
  xadUINT32 BackTree[1000];
};

static void SITLZAH_move(xadUINT32 *p, xadUINT32 *q, xadUINT32 n)
{
  if(p > q)
  {
    while(n-- > 0)
      *q++ = *p++;
  }
  else
  {
    p += n;
    q += n;
    while(n-- > 0)
      *--q = *--p;
  }
}

static xadINT32 SIT_lzah(struct xadInOut *io)
{
  xadINT32 i, i1, j, k, l, ch, byte, offs, skip;
  xadUINT32 bufptr = 0;
  struct SITLZAHData *dat;
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

  if((dat = (struct SITLZAHData *) xadAllocVec(XADM sizeof(struct SITLZAHData), XADMEMF_CLEAR|XADMEMF_PUBLIC)))
  {
    /* init buffer */
    for(i = 0; i < SITLZAH_N; i++)
    {
      dat->Frequ[i] = 1;
      dat->ForwTree[i] = i + SITLZAH_T;
      dat->BackTree[i + SITLZAH_T] = i;
    }
    for(i = 0, j = SITLZAH_N; j < SITLZAH_T; i += 2, j++)
    {
      dat->Frequ[j] = dat->Frequ[i] + dat->Frequ[i + 1];
      dat->ForwTree[j] = i;
      dat->BackTree[i] = j;
      dat->BackTree[i + 1] = j;
    }
    dat->Frequ[SITLZAH_T] = 0xffff;
    dat->BackTree[SITLZAH_T - 1] = 0;

    for(i = 0; i < 4096; i++)
      dat->buf[i] = ' ';

    while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      ch = dat->ForwTree[SITLZAH_T - 1];
      while(ch < SITLZAH_T)
        ch = dat->ForwTree[ch + xadIOGetBitsHigh(io, 1)];
      ch -= SITLZAH_T;
      if(dat->Frequ[SITLZAH_T - 1] >= 0x8000) /* need to reorder */
      {
        j = 0;
        for(i = 0; i < SITLZAH_T; i++)
        {
          if(dat->ForwTree[i] >= SITLZAH_T)
          {
            dat->Frequ[j] = ((dat->Frequ[i] + 1) >> 1);
            dat->ForwTree[j] = dat->ForwTree[i];
            j++;
          }
        }
        j = SITLZAH_N;
        for(i = 0; i < SITLZAH_T; i += 2)
        {
          k = i + 1;
          l = dat->Frequ[i] + dat->Frequ[k];
          dat->Frequ[j] = l;
          k = j - 1;
          while(l < dat->Frequ[k])
            k--;
          k = k + 1;
          SITLZAH_move(dat->Frequ + k, dat->Frequ + k + 1, j - k);
          dat->Frequ[k] = l;
          SITLZAH_move(dat->ForwTree + k, dat->ForwTree + k + 1, j - k);
          dat->ForwTree[k] = i;
          j++;
        }
        for(i = 0; i < SITLZAH_T; i++)
        {
          k = dat->ForwTree[i];
          if(k >= SITLZAH_T)
            dat->BackTree[k] = i;
          else
          {
            dat->BackTree[k] = i;
            dat->BackTree[k + 1] = i;
          }
        }
      }

      i = dat->BackTree[ch + SITLZAH_T];
      do
      {
        j = ++dat->Frequ[i];
        i1 = i + 1;
        if(dat->Frequ[i1] < j)
        {
          while(dat->Frequ[++i1] < j)
            ;
          i1--;
          dat->Frequ[i] = dat->Frequ[i1];
          dat->Frequ[i1] = j;

          j = dat->ForwTree[i];
          dat->BackTree[j] = i1;
          if(j < SITLZAH_T)
            dat->BackTree[j + 1] = i1;
          dat->ForwTree[i] = dat->ForwTree[i1];
          dat->ForwTree[i1] = j;
          j = dat->ForwTree[i];
          dat->BackTree[j] = i;
          if(j < SITLZAH_T)
            dat->BackTree[j + 1] = i;
          i = i1;
        }
        i = dat->BackTree[i];
      } while(i != 0);

      if(ch < 256)
      {
        dat->buf[bufptr++] = xadIOPutChar(io, ch);
        bufptr &= 0xFFF;
      }
      else
      {
        byte = xadIOGetBitsHigh(io, 8);
        skip = SITLZAH_HuffLength[byte] - 2;
        offs = (SITLZAH_HuffCode[byte]<<4) | (((byte << skip)  + xadIOGetBitsHigh(io, skip)) & 0x3f);
        offs = ((bufptr - offs - 1) & 0xfff);
        ch = ch - 253;
        while(ch-- > 0)
        {
          dat->buf[bufptr++] = xadIOPutChar(io, dat->buf[offs++ & 0xfff]);
          bufptr &= 0xFFF;
        }
      }
    }
    xadFreeObjectA(XADM dat, 0);
  }
  else
    return XADERR_NOMEMORY;

  return io->xio_Error;
}

/*****************************************************************************/

struct SITMWData {
  xadUINT16 dict[16385];
  xadUINT16 stack[16384];
};

static void SITMW_out(struct xadInOut *io, struct SITMWData *dat, xadINT32 ptr)
{
  xadUINT16 stack_ptr = 1;

  dat->stack[0] = ptr;
  while(stack_ptr)
  {
    ptr = dat->stack[--stack_ptr];
    while(ptr >= 256)
    {
      dat->stack[stack_ptr++] = dat->dict[ptr];
      ptr = dat->dict[ptr - 1];
    }
    xadIOPutChar(io, (xadUINT8) ptr);
  }
}

static xadINT32 SIT_mw(struct xadInOut *io)
{
  struct SITMWData *dat;
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

  if((dat = (struct SITMWData *) xadAllocVec(XADM sizeof(struct SITMWData), XADMEMF_CLEAR|XADMEMF_PUBLIC)))
  {
    xadINT32 ptr, max, max1, bits;

    while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      max = 256;
      max1 = max << 1;
      bits = 9;
      ptr = xadIOGetBitsLow(io, bits);
      if(ptr < max)
      {
        dat->dict[255] = ptr;
        SITMW_out(io, dat, ptr);
        while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)) &&
        (ptr = xadIOGetBitsLow(io, bits)) < max)
        {
          dat->dict[max++] = ptr;
          if(max == max1)
          {
            max1 <<= 1;
            bits++;
          }
          SITMW_out(io, dat, ptr);
        }
      }
      if(ptr > max)
        break;
    }

    xadFreeObjectA(XADM dat, 0);
  }
  else
    return XADERR_NOMEMORY;

  return io->xio_Error;
}

/*****************************************************************************/

struct SIT13Buffer {
  xadUINT16 data;
  xadINT8  bits;
};

struct SIT13Store {
  xadINT16  freq;
  xadUINT16 d1;
  xadUINT16 d2;
};

struct SIT13Data {
  xadUINT16              MaxBits;
  struct SIT13Store  Buffer4[0xE08];
  struct SIT13Buffer Buffer1[0x1000];
  struct SIT13Buffer Buffer2[0x1000];
  struct SIT13Buffer Buffer3[0x1000];
  struct SIT13Buffer Buffer3b[0x1000];
  struct SIT13Buffer Buffer5[0x141];
  xadUINT8              TextBuf[658];
  xadUINT8              Window[0x10000];
};

static const xadUINT8 SIT13Bits[16] = {0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15};
static const xadUINT16 SIT13Info[37] = {
  0x5D8, 0x058, 0x040, 0x0C0, 0x000, 0x078, 0x02B, 0x014,
  0x00C, 0x01C, 0x01B, 0x00B, 0x010, 0x020, 0x038, 0x018,
  0x0D8, 0xBD8, 0x180, 0x680, 0x380, 0xF80, 0x780, 0x480,
  0x080, 0x280, 0x3D8, 0xFD8, 0x7D8, 0x9D8, 0x1D8, 0x004,
  0x001, 0x002, 0x007, 0x003, 0x008
};
static const xadUINT16 SIT13InfoBits[37] = {
  11,  8,  8,  8,  8,  7,  6,  5,  5,  5,  5,  6,  5,  6,  7,  7,
   9, 12, 10, 11, 11, 12, 12, 11, 11, 11, 12, 12, 12, 12, 12,  5,
   2,  2,  3,  4,  5
};
static const xadUINT16 SIT13StaticPos[5] = {0, 330, 661, 991, 1323};
static const xadUINT8 SIT13StaticBits[5] = {11, 13, 14, 11, 11};
static const xadUINT8 SIT13Static[1655] = {
  0xB8,0x98,0x78,0x77,0x75,0x97,0x76,0x87,0x77,0x77,0x77,0x78,0x67,0x87,0x68,0x67,0x3B,0x77,0x78,0x67,
  0x77,0x77,0x77,0x59,0x76,0x87,0x77,0x77,0x77,0x77,0x77,0x77,0x76,0x87,0x67,0x87,0x77,0x77,0x75,0x88,
  0x59,0x75,0x79,0x77,0x78,0x68,0x77,0x67,0x73,0xB6,0x65,0xB6,0x76,0x97,0x67,0x47,0x9A,0x2A,0x4A,0x87,
  0x77,0x78,0x67,0x86,0x78,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,0x77,0x77,0x77,
  0x68,0x77,0x77,0x77,0x67,0x87,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x68,0x77,0x77,0x68,0x77,0x77,0x77,
  0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,0x77,0x67,0x87,
  0x68,0x77,0x77,0x77,0x68,0x77,0x68,0x63,0x86,0x7A,0x87,0x77,0x77,0x87,0x76,0x87,0x77,0x77,0x77,0x77,
  0x77,0x77,0x77,0x77,0x77,0x76,0x86,0x77,0x86,0x86,0x86,0x86,0x87,0x76,0x86,0x87,0x67,0x74,0xA7,0x86,
  0x36,0x88,0x78,0x76,0x87,0x76,0x96,0x87,0x77,0x84,0xA6,0x86,0x87,0x76,0x92,0xB5,0x94,0xA6,0x96,0x85,
  0x78,0x75,0x96,0x86,0x86,0x75,0xA7,0x67,0x87,0x85,0x87,0x85,0x95,0x77,0x77,0x85,0xA3,0xA7,0x93,0x87,
  0x86,0x94,0x85,0xA8,0x67,0x85,0xA5,0x95,0x86,0x68,0x67,0x77,0x96,0x78,0x75,0x86,0x77,0xA5,0x67,0x87,
  0x85,0xA6,0x75,0x96,0x85,0x87,0x95,0x95,0x87,0x86,0x94,0xA5,0x86,0x85,0x87,0x86,0x86,0x86,0x86,0x77,
  0x67,0x76,0x66,0x9A,0x75,0xA5,0x94,0x97,0x76,0x96,0x76,0x95,0x86,0x77,0x86,0x87,0x75,0xA5,0x96,0x85,
  0x86,0x96,0x86,0x86,0x85,0x96,0x86,0x76,0x95,0x86,0x95,0x95,0x95,0x87,0x76,0x87,0x76,0x96,0x85,0x78,
  0x75,0xA6,0x85,0x86,0x95,0x86,0x95,0x86,0x45,0x69,0x78,0x77,0x87,0x67,0x69,0x58,0x79,0x68,0x78,0x87,
  0x78,0x66,0x88,0x68,0x68,0x77,0x76,0x87,0x68,0x68,0x69,0x58,0x5A,0x4B,0x76,0x88,0x69,0x67,0xA7,0x70,
  0x9F,0x90,0xA4,0x84,0x77,0x77,0x77,0x89,0x17,0x77,0x7B,0xA7,0x86,0x87,0x77,0x68,0x68,0x69,0x67,0x78,
  0x77,0x78,0x76,0x87,0x77,0x76,0x73,0xB6,0x87,0x96,0x66,0x87,0x76,0x85,0x87,0x78,0x77,0x77,0x86,0x77,
  0x86,0x78,0x66,0x76,0x77,0x87,0x86,0x78,0x76,0x76,0x86,0xA5,0x67,0x97,0x77,0x87,0x87,0x76,0x66,0x59,
  0x67,0x59,0x77,0x6A,0x65,0x86,0x78,0x94,0x77,0x88,0x77,0x78,0x86,0x86,0x76,0x88,0x76,0x87,0x67,0x87,
  0x77,0x77,0x76,0x87,0x86,0x77,0x77,0x77,0x86,0x86,0x76,0x96,0x77,0x77,0x76,0x78,0x86,0x86,0x86,0x95,
  0x86,0x96,0x85,0x95,0x86,0x87,0x75,0x88,0x77,0x87,0x57,0x78,0x76,0x86,0x76,0x96,0x86,0x87,0x76,0x87,
  0x86,0x76,0x77,0x86,0x78,0x78,0x57,0x87,0x86,0x76,0x85,0xA5,0x87,0x76,0x86,0x86,0x85,0x86,0x53,0x98,
  0x78,0x78,0x77,0x87,0x79,0x67,0x79,0x85,0x87,0x69,0x67,0x68,0x78,0x69,0x68,0x69,0x58,0x87,0x66,0x97,
  0x68,0x68,0x76,0x85,0x78,0x87,0x67,0x97,0x67,0x74,0xA2,0x28,0x77,0x78,0x77,0x77,0x78,0x68,0x67,0x78,
  0x77,0x78,0x68,0x68,0x77,0x59,0x67,0x5A,0x68,0x68,0x68,0x68,0x68,0x68,0x67,0x77,0x78,0x68,0x68,0x78,
  0x59,0x58,0x76,0x77,0x68,0x78,0x68,0x59,0x69,0x58,0x68,0x68,0x67,0x78,0x77,0x78,0x69,0x58,0x68,0x57,
  0x78,0x67,0x78,0x76,0x88,0x58,0x67,0x7A,0x46,0x88,0x77,0x78,0x68,0x68,0x66,0x78,0x78,0x68,0x68,0x59,
  0x68,0x69,0x68,0x59,0x67,0x78,0x59,0x58,0x69,0x59,0x67,0x68,0x67,0x69,0x69,0x57,0x79,0x68,0x59,0x59,
  0x59,0x68,0x68,0x68,0x58,0x78,0x67,0x59,0x68,0x78,0x59,0x58,0x78,0x58,0x76,0x78,0x68,0x68,0x68,0x69,
  0x59,0x67,0x68,0x69,0x59,0x59,0x58,0x69,0x59,0x59,0x58,0x5A,0x58,0x68,0x68,0x59,0x58,0x68,0x66,0x47,
  0x88,0x77,0x87,0x77,0x87,0x76,0x87,0x87,0x87,0x77,0x77,0x87,0x67,0x96,0x78,0x76,0x87,0x68,0x77,0x77,
  0x76,0x86,0x96,0x86,0x88,0x77,0x85,0x86,0x8B,0x76,0x0A,0xF9,0x07,0x38,0x57,0x67,0x77,0x78,0x77,0x91,
  0x77,0xD7,0x77,0x7A,0x67,0x3C,0x68,0x68,0x77,0x68,0x78,0x59,0x77,0x68,0x77,0x68,0x76,0x77,0x69,0x68,
  0x68,0x68,0x68,0x67,0x68,0x68,0x77,0x87,0x77,0x67,0x78,0x68,0x67,0x58,0x78,0x68,0x77,0x68,0x78,0x67,
  0x68,0x68,0x67,0x78,0x77,0x77,0x87,0x77,0x76,0x67,0x86,0x85,0x87,0x86,0x97,0x58,0x67,0x79,0x57,0x77,
  0x87,0x77,0x87,0x77,0x76,0x59,0x78,0x77,0x77,0x68,0x77,0x77,0x76,0x78,0x77,0x77,0x77,0x76,0x87,0x77,
  0x77,0x68,0x77,0x77,0x77,0x67,0x78,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x68,0x77,0x76,0x68,0x87,0x77,
  0x77,0x77,0x77,0x68,0x77,0x68,0x77,0x77,0x77,0x77,0x77,0x77,0x76,0x78,0x77,0x77,0x76,0x87,0x77,0x77,
  0x67,0x78,0x77,0x77,0x76,0x78,0x67,0x68,0x68,0x29,0x77,0x88,0x78,0x78,0x77,0x68,0x77,0x77,0x77,0x77,
  0x77,0x77,0x77,0x77,0x4A,0x77,0x4A,0x74,0x77,0x77,0x68,0xA4,0x7A,0x47,0x76,0x86,0x78,0x76,0x7A,0x4A,
  0x83,0xB2,0x87,0x77,0x87,0x76,0x96,0x86,0x96,0x76,0x78,0x87,0x77,0x85,0x87,0x85,0x96,0x65,0xB5,0x95,
  0x96,0x77,0x77,0x86,0x76,0x86,0x86,0x87,0x86,0x86,0x76,0x96,0x96,0x57,0x77,0x85,0x97,0x85,0x86,0xA5,
  0x86,0x85,0x87,0x77,0x68,0x78,0x77,0x95,0x86,0x75,0x87,0x76,0x86,0x79,0x68,0x84,0x96,0x76,0xB3,0x87,
  0x77,0x68,0x86,0xA5,0x77,0x56,0xB6,0x68,0x85,0x93,0xB6,0x95,0x95,0x85,0x95,0xA5,0x95,0x95,0x69,0x85,
  0x95,0x85,0x86,0x86,0x97,0x84,0x85,0xB6,0x84,0xA5,0x95,0xA4,0x95,0x95,0x95,0x68,0x95,0x66,0xA6,0x95,
  0x95,0x95,0x86,0x93,0xB5,0x86,0x77,0x94,0x96,0x95,0x96,0x85,0x68,0x94,0x87,0x95,0x86,0x86,0x93,0xB4,
  0xA3,0xB3,0xA6,0x86,0x85,0x85,0x96,0x76,0x86,0x64,0x69,0x78,0x68,0x78,0x78,0x77,0x67,0x79,0x68,0x79,
  0x59,0x56,0x87,0x98,0x68,0x78,0x76,0x88,0x68,0x68,0x67,0x76,0x87,0x68,0x78,0x76,0x78,0x77,0x78,0xA6,
  0x80,0xAF,0x81,0x38,0x47,0x67,0x77,0x78,0x77,0x89,0x07,0x79,0xB7,0x87,0x86,0x86,0x87,0x86,0x87,0x76,
  0x78,0x77,0x87,0x66,0x96,0x86,0x86,0x74,0xA6,0x87,0x86,0x77,0x86,0x77,0x76,0x77,0x77,0x87,0x77,0x77,
  0x77,0x77,0x87,0x65,0x78,0x77,0x78,0x75,0x88,0x85,0x76,0x87,0x95,0x77,0x86,0x87,0x86,0x96,0x85,0x76,
  0x69,0x67,0x59,0x77,0x6A,0x65,0x86,0x78,0x94,0x77,0x88,0x77,0x78,0x85,0x96,0x65,0x98,0x77,0x87,0x67,
  0x86,0x77,0x87,0x66,0x87,0x86,0x86,0x86,0x77,0x86,0x86,0x76,0x87,0x86,0x77,0x76,0x87,0x77,0x86,0x86,
  0x86,0x87,0x76,0x95,0x86,0x86,0x87,0x65,0x97,0x86,0x87,0x76,0x86,0x86,0x87,0x75,0x88,0x76,0x87,0x76,
  0x87,0x76,0x77,0x77,0x86,0x78,0x76,0x76,0x96,0x78,0x76,0x77,0x86,0x77,0x77,0x76,0x96,0x75,0x95,0x56,
  0x87,0x87,0x87,0x78,0x88,0x67,0x87,0x87,0x58,0x87,0x77,0x87,0x77,0x76,0x87,0x96,0x59,0x88,0x37,0x89,
  0x69,0x69,0x84,0x96,0x67,0x77,0x57,0x4B,0x58,0xB7,0x80,0x8E,0x0D,0x78,0x87,0x77,0x87,0x68,0x79,0x49,
  0x76,0x78,0x77,0x5A,0x67,0x69,0x68,0x68,0x68,0x4A,0x68,0x69,0x67,0x69,0x59,0x58,0x68,0x67,0x69,0x77,
  0x77,0x69,0x68,0x68,0x66,0x68,0x87,0x68,0x77,0x5A,0x68,0x67,0x68,0x68,0x67,0x78,0x78,0x67,0x6A,0x59,
  0x67,0x57,0x95,0x78,0x77,0x86,0x88,0x57,0x77,0x68,0x67,0x79,0x76,0x76,0x98,0x68,0x75,0x68,0x88,0x58,
  0x87,0x5A,0x57,0x79,0x67,0x59,0x78,0x49,0x58,0x77,0x79,0x49,0x68,0x59,0x77,0x68,0x78,0x48,0x79,0x67,
  0x68,0x59,0x68,0x68,0x59,0x75,0x6A,0x68,0x76,0x4C,0x67,0x77,0x78,0x59,0x69,0x56,0x96,0x68,0x68,0x68,
  0x77,0x69,0x67,0x68,0x67,0x78,0x69,0x68,0x58,0x59,0x68,0x68,0x69,0x49,0x77,0x59,0x67,0x69,0x67,0x68,
  0x65,0x48,0x77,0x87,0x86,0x96,0x88,0x75,0x87,0x96,0x87,0x95,0x87,0x77,0x68,0x86,0x77,0x77,0x96,0x68,
  0x86,0x77,0x85,0x5A,0x81,0xD5,0x95,0x68,0x99,0x74,0x98,0x77,0x09,0xF9,0x0A,0x5A,0x66,0x58,0x77,0x87,
  0x91,0x77,0x77,0xE9,0x77,0x77,0x77,0x76,0x87,0x75,0x97,0x77,0x77,0x77,0x78,0x68,0x68,0x68,0x67,0x3B,
  0x59,0x77,0x77,0x57,0x79,0x57,0x86,0x87,0x67,0x97,0x77,0x57,0x79,0x77,0x77,0x75,0x95,0x77,0x79,0x75,
  0x97,0x57,0x77,0x79,0x58,0x69,0x77,0x77,0x77,0x77,0x77,0x75,0x86,0x77,0x87,0x58,0x95,0x78,0x65,0x8A,
  0x39,0x58,0x87,0x96,0x87,0x77,0x77,0x77,0x86,0x87,0x76,0x78,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,
  0x77,0x68,0x77,0x68,0x77,0x67,0x86,0x77,0x78,0x77,0x77,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,0x68,
  0x77,0x68,0x77,0x67,0x78,0x77,0x77,0x68,0x68,0x76,0x87,0x68,0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x77,
  0x77,0x77,0x77,0x68,0x77,0x77,0x77,0x68,0x68,0x68,0x76,0x38,0x97,0x67,0x79,0x77,0x77,0x77,0x77,0x77,
  0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x78,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x77,0x68,
  0x72,0xC5,0x86,0x86,0x98,0x77,0x86,0x78,0x1C,0x85,0x2E,0x77,0x77,0x77,0x87,0x86,0x76,0x86,0x86,0xA0,
  0xBD,0x49,0x97,0x66,0x48,0x88,0x48,0x68,0x86,0x78,0x77,0x77,0x78,0x66,0xA6,0x87,0x83,0x85,0x88,0x78,
  0x66,0xA7,0x56,0x87,0x6A,0x46,0x89,0x76,0xA7,0x76,0x87,0x74,0xA2,0x86,0x77,0x79,0x66,0xB6,0x48,0x67,
  0x8A,0x36,0x88,0x77,0xA5,0xA5,0xB1,0xE9,0x39,0x78,0x78,0x75,0x87,0x77,0x77,0x77,0x68,0x58,0x79,0x69,
  0x4A,0x59,0x29,0x6A,0x3C,0x3B,0x46,0x78,0x75,0x89,0x76,0x89,0x4A,0x56,0x88,0x3B,0x66,0x88,0x68,0x87,
  0x57,0x97,0x38,0x87,0x56,0xB7,0x84,0x88,0x67,0x57,0x95,0xA8,0x59,0x77,0x68,0x4A,0x49,0x69,0x57,0x6A,
  0x59,0x58,0x67,0x87,0x5A,0x75,0x78,0x69,0x56,0x97,0x77,0x73,0x08,0x78,0x78,0x77,0x87,0x78,0x77,0x78,
  0x77,0x77,0x87,0x78,0x68,0x77,0x77,0x87,0x78,0x76,0x86,0x97,0x58,0x77,0x78,0x58,0x78,0x77,0x68,0x78,
  0x75,0x95,0xB7,0x70,0x8F,0x80,0xA6,0x87,0x65,0x66,0x78,0x7A,0x17,0x77,0x70,
};

static void SIT13_Func1(struct SIT13Data *s, struct SIT13Buffer *buf, xadUINT32 info, xadUINT16 bits, xadUINT16 num)
{
  xadUINT32 i, j;

  if(bits <= 12)
  {
    for(i = 0; i < (1<<12); i += (1<<bits))
    {
      buf[info+i].data = num;
      buf[info+i].bits = bits;
    }
  }
  else
  {
    j = bits-12;

    if(buf[info & 0xFFF].bits != 0x1F)
    {
      buf[info & 0xFFF].bits = 0x1F;
      buf[info & 0xFFF].data = s->MaxBits++;
    }
    bits = buf[info & 0xFFF].data;
    info >>= 12;

    while(j--)
    {
      xadUINT16 *a;

      a = info & 1 ? &s->Buffer4[bits].d2 : &s->Buffer4[bits].d1;
      if(!*a)
        *a = s->MaxBits++;
      bits = *a;
      info >>= 1;
    }
    s->Buffer4[bits].freq = num;
  }
}

static void SIT13_SortTree(struct SIT13Data *s, struct SIT13Buffer *buf, struct SIT13Buffer *buf2)
{
  xadUINT16 td;
  xadINT8 tb;

  struct SIT13Buffer *a, *b;

  while(buf2-1 > buf)
  {
    a = buf;
    b = buf2;

    for(;;)
    {
      while(++a < buf2)
      {
        tb = a->bits - buf->bits;
        if(tb > 0 || (!tb && (a->data >= buf->data)))
          break;
      }
      while(--b > buf)
      {
        tb = b->bits - buf->bits;
        if(tb < 0 || (!tb && (b->data <= buf->data)))
          break;
      }
      if(b < a)
        break;
      else
      {
        tb = a->bits;
        td = a->data;
        a->bits = b->bits;
        a->data = b->data;
        b->bits = tb;
        b->data = td;
      }
    }
    if(b == buf)
      ++buf;
    else
    {
      tb = buf->bits;
      td = buf->data;
      buf->bits = b->bits;
      buf->data = b->data;
      b->bits = tb;
      b->data = td;
      if(buf2-b-1 > b-buf)
      {
        SIT13_SortTree(s, buf, b);
        buf = b+1;
      }
      else
      {
        SIT13_SortTree(s, b+1, buf2);
        buf2 = b;
      }
    }
  }
}

static void SIT13_Func2(struct SIT13Data *s, struct SIT13Buffer *buf, xadUINT16 bits, struct SIT13Buffer *buf2)
{
  xadINT32 i, j, k, l, m, n;

  SIT13_SortTree(s, buf2, buf2 + bits);

  l = k = j = 0;
  for(i = 0; i < bits; ++i)
  {
    l += k;
    m = buf2[i].bits;
    if(m != j)
    {
      if((j = m) == -1)
        k = 0;
      else
        k = 1 << (32-j);
    }
    if(j > 0)
    {
      for(n = m = 0; n < 8*4; n += 4)
        m += SIT13Bits[(l>>n)&0xF]<<(7*4-n);
      SIT13_Func1(s, buf, m, j, buf2[i].data);
fprintf(stderr,"code:%x rev:%x length:%d val:%d\n",l,m,j,buf2[i].data);
    }
  }
}

static void SIT13_CreateStaticTree(struct SIT13Data *s, struct SIT13Buffer *buf, xadUINT16 bits, xadUINT8 *bitsbuf)
{
  xadUINT32 i;

  for(i = 0; i < bits; ++i)
  {
    s->Buffer5[i].data = i;
    s->Buffer5[i].bits = bitsbuf[i];
  }
  SIT13_Func2(s, buf, bits, s->Buffer5);
}

static void SIT13InitInfo(struct SIT13Data *s, xadUINT8 id)
{
  xadINT32 i;
  xadUINT8 k, l = 0, *a, *b;

  a = s->TextBuf;
  b = (xadUINT8 *) SIT13Static+SIT13StaticPos[id-1];
  id &= 1;

  for(i = 658; i; --i)
  {
    k = id ? *b >> 4 : *(b++) & 0xF; id ^=1;

    if(!k)
    {
      l -= id ? *b >> 4 : *(b++) & 0xF; id ^= 1;
    }
    else
    {
      if(k == 15)
      {
        l += id ? *b >> 4 : *(b++) & 0xF; id ^= 1;
      }
      else
        l += k-7;
    }
    *(a++) = l;
  }
}

static void SIT13_Extract(struct SIT13Data *s, struct xadInOut *io)
{
  xadUINT32 wpos = 0, j, k, l, size;
  struct SIT13Buffer *buf = s->Buffer3;

  while(!io->xio_Error)
  {
    k = xadIOReadBitsLow(io, 12);
    if((j = buf[k].bits) <= 12)
    {
      l = buf[k].data;
      xadIODropBitsLow(io, j);
    }
    else
    {
      xadIODropBitsLow(io, 12);

      j = buf[k].data;
      while(s->Buffer4[j].freq == -1)
        j = xadIOGetBitsLow(io, 1) ? s->Buffer4[j].d2 : s->Buffer4[j].d1;
      l = s->Buffer4[j].freq;
    }
fprintf(stderr,"lit: %x\n",l);
    if(l < 0x100)
    {
      s->Window[wpos++] = xadIOPutChar(io, l);
      wpos &= 0xFFFF;
      buf = s->Buffer3;
    }
    else
    {
      buf = s->Buffer3b;
      if(l < 0x13E)
        size = l - 0x100 + 3;
      else
      {
        if(l == 0x13E)
          size = xadIOGetBitsLow(io, 10);
        else
        {
          if(l == 0x140)
            return;
          size = xadIOGetBitsLow(io, 15);
        }
        size += 65;
      }
      j = xadIOReadBitsLow(io, 12);
      k = s->Buffer2[j].bits;
      if(k <= 12)
      {
        l = s->Buffer2[j].data;
        xadIODropBitsLow(io, k);
      }
      else
      {
        xadIODropBitsLow(io, 12);
        j = s->Buffer2[j].data;
        while(s->Buffer4[j].freq == -1)
          j = xadIOGetBitsLow(io, 1) ? s->Buffer4[j].d2 : s->Buffer4[j].d1;
        l = s->Buffer4[j].freq;
      }
      k = 0;
      if(l--)
        k = (1 << l) | xadIOGetBitsLow(io, l);
      l = wpos+0x10000-(k+1);
      while(size--)
      {
        l &= 0xFFFF;
        s->Window[wpos++] = xadIOPutChar(io, s->Window[l++]);
        wpos &= 0xFFFF;
      }
    } /* l >= 0x100 */
  }
}

static void SIT13_CreateTree(struct SIT13Data *s, struct xadInOut *io, struct SIT13Buffer *buf, xadUINT16 num)
{
  struct SIT13Buffer *b;
  xadUINT32 i;
  xadUINT16 data;
  xadINT8 bi = 0;

  for(i = 0; i < num; ++i)
  {
    b = &s->Buffer1[xadIOReadBitsLow(io, 12)];
    data = b->data;
    xadIODropBitsLow(io, b->bits);

    switch(data-0x1F)
    {
    case 0: bi = -1; break;
    case 1: ++bi; break;
    case 2: --bi; break;
    case 3:
      if(xadIOGetBitsLow(io, 1))
        s->Buffer5[i++].bits = bi;
      break;
    case 4:
      data = xadIOGetBitsLow(io, 3)+2;
      while(data--)
        s->Buffer5[i++].bits = bi;
      break;
    case 5:
      data = xadIOGetBitsLow(io, 6)+10;
      while(data--)
        s->Buffer5[i++].bits = bi;
      break;
    default: bi = data+1; break;
    }
    s->Buffer5[i].bits = bi;
  }
  for(i = 0; i < num; ++i)
    s->Buffer5[i].data = i;
  SIT13_Func2(s, buf, num, s->Buffer5);
}

static xadINT32 SIT_13(struct xadInOut *io)
{
  xadUINT32 i, j;
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct SIT13Data *s;

  if((s = xadAllocVec(XADM sizeof(struct SIT13Data), XADMEMF_CLEAR)))
  {
    s->MaxBits = 1;
    for(i = 0; i < 37; ++i)
      SIT13_Func1(s, s->Buffer1, SIT13Info[i], SIT13InfoBits[i], i);
    for(i = 1; i < 0x704; ++i)
    {
      /* s->Buffer4[i].d1 = s->Buffer4[i].d2 = 0; */
      s->Buffer4[i].freq = -1;
    }

    j = xadIOGetChar(io);
    i = j>>4;
    if(i > 5)
      io->xio_Error = XADERR_ILLEGALDATA;
    else if(i)
    {
      SIT13InitInfo(s, i--);
      SIT13_CreateStaticTree(s, s->Buffer3, 0x141, s->TextBuf);
      SIT13_CreateStaticTree(s, s->Buffer3b, 0x141, s->TextBuf+0x141);
      SIT13_CreateStaticTree(s, s->Buffer2, SIT13StaticBits[i], s->TextBuf+0x282);
    }
    else
    {
      SIT13_CreateTree(s, io, s->Buffer3, 0x141);
      if(j&8)
        xadCopyMem(XADM (xadPTR) s->Buffer3, (xadPTR) s->Buffer3b, 0x1000*sizeof(struct SIT13Buffer));
      else
        SIT13_CreateTree(s, io, s->Buffer3b, 0x141);
      j = (j&7)+10;
      SIT13_CreateTree(s, io, s->Buffer2, j);
    }
    if(!io->xio_Error)
      SIT13_Extract(s, io);
    xadFreeObjectA(XADM s, 0);
  }
  return io->xio_Error;
}

/*****************************************************************************/

struct SIT14Data {
  struct xadInOut *io;
  xadUINT8 code[308];
  xadUINT8 codecopy[308];
  xadUINT16 freq[308];
  xadUINT32 buff[308];

  xadUINT8 var1[52];
  xadUINT16 var2[52];
  xadUINT16 var3[75*2];

  xadUINT8 var4[76];
  xadUINT32 var5[75];
  xadUINT8 var6[1024];
  xadUINT16 var7[308*2];
  xadUINT8 var8[0x4000];

  xadUINT8 Window[0x40000];
};

static void SIT14_Update(xadUINT16 first, xadUINT16 last, xadUINT8 *code, xadUINT16 *freq)
{
  xadUINT16 i, j;

  while(last-first > 1)
  {
    i = first;
    j = last;

    do
    {
      while(++i < last && code[first] > code[i])
        ;
      while(--j > first && code[first] < code[j])
        ;
      if(j > i)
      {
        xadUINT16 t;
        t = code[i]; code[i] = code[j]; code[j] = t;
        t = freq[i]; freq[i] = freq[j]; freq[j] = t;
      }
    } while(j > i);

    if(first != j)
    {
      {
        xadUINT16 t;
        t = code[first]; code[first] = code[j]; code[j] = t;
        t = freq[first]; freq[first] = freq[j]; freq[j] = t;
      }

      i = j+1;
      if(last-i <= j-first)
      {
        SIT14_Update(i, last, code, freq);
        last = j;
      }
      else
      {
        SIT14_Update(first, j, code, freq);
        first = i;
      }
    }
    else
      ++first;
  }
}

static void SIT14_ReadTree(struct SIT14Data *dat, xadUINT16 codesize, xadUINT16 *result)
{
  xadUINT32 size, i, j, k, l, m, n, o;

  k = xadIOGetBitsLow(dat->io, 1);
  j = xadIOGetBitsLow(dat->io, 2)+2;
  o = xadIOGetBitsLow(dat->io, 3)+1;
  size = 1<<j;
  m = size-1;
  k = k ? m-1 : -1;
  if(xadIOGetBitsLow(dat->io, 2)&1) /* skip 1 bit! */
  {
    /* requirements for this call: dat->buff[32], dat->code[32], dat->freq[32*2] */
    SIT14_ReadTree(dat, size, dat->freq);
    for(i = 0; i < codesize; )
    {
      l = 0;
      do
      {
        l = dat->freq[l + xadIOGetBitsLow(dat->io, 1)];
        n = size<<1;
      } while(n > l);
      l -= n;
      if(k != l)
      {
        if(l == m)
        {
          l = 0;
          do
          {
            l = dat->freq[l + xadIOGetBitsLow(dat->io, 1)];
            n = size<<1;
          } while(n > l);
          l += 3-n;
          while(l--)
          {
            dat->code[i] = dat->code[i-1];
            ++i;
          }
        }
        else
          dat->code[i++] = l+o;
      }
      else
        dat->code[i++] = 0;
    }
  }
  else
  {
    for(i = 0; i < codesize; )
    {
      l = xadIOGetBitsLow(dat->io, j);
      if(k != l)
      {
        if(l == m)
        {
          l = xadIOGetBitsLow(dat->io, j)+3;
          while(l--)
          {
            dat->code[i] = dat->code[i-1];
            ++i;
          }
        }
        else
          dat->code[i++] = l+o;
      }
      else
        dat->code[i++] = 0;
    }
  }

  for(i = 0; i < codesize; ++i)
  {
    dat->codecopy[i] = dat->code[i];
    dat->freq[i] = i;
  }
  SIT14_Update(0, codesize, dat->codecopy, dat->freq);

  for(i = 0; i < codesize && !dat->codecopy[i]; ++i)
    ; /* find first nonempty */
  for(j = 0; i < codesize; ++i, ++j)
  {
    if(i)
      j <<= (dat->codecopy[i] - dat->codecopy[i-1]);

    k = dat->codecopy[i]; m = 0;
    for(l = j; k--; l >>= 1)
      m = (m << 1) | (l&1);

    dat->buff[dat->freq[i]] = m;
  }

  for(i = 0; i < codesize*2; ++i)
    result[i] = 0;

  j = 2;
  for(i = 0; i < codesize; ++i)
  {
    l = 0;
    m = dat->buff[i];

    for(k = 0; k < dat->code[i]; ++k)
    {
      l += (m&1);
      if(dat->code[i]-1 <= k)
        result[l] = codesize*2+i;
      else
      {
        if(!result[l])
        {
          result[l] = j; j += 2;
        }
        l = result[l];
      }
      m >>= 1;
    }
  }
  xadIOByteBoundary(dat->io);
}

static xadINT32 SIT_14(struct xadInOut *io)
{
  xadUINT32 i, j, k, l, m, n;
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  struct SIT14Data *dat;

  if((dat = (struct SIT14Data *) xadAllocVec(XADM sizeof(struct SIT14Data), XADMEMF_ANY|XADMEMF_CLEAR)))
  {
    dat->io = io;

    /* initialization */
    for(i = k = 0; i < 52; ++i)
    {
      dat->var2[i] = k;
      k += (1<<(dat->var1[i] = ((i >= 4) ? ((i-4)>>2) : 0)));
    }
    for(i = 0; i < 4; ++i)
      dat->var8[i] = i;
    for(m = 1, l = 4; i < 0x4000; m <<= 1) /* i is 4 */
    {
      for(n = l+4; l < n; ++l)
      {
        for(j = 0; j < m; ++j)
          dat->var8[i++] = l;
      }
    }
    for(i = 0, k = 1; i < 75; ++i)
    {
      dat->var5[i] = k;
      k += (1<<(dat->var4[i] = (i >= 3 ? ((i-3)>>2) : 0)));
    }
    for(i = 0; i < 4; ++i)
      dat->var6[i] = i-1;
    for(m = 1, l = 3; i < 0x400; m <<= 1) /* i is 4 */
    {
      for(n = l+4; l < n; ++l)
      {
        for(j = 0; j < m; ++j)
          dat->var6[i++] = l;
      }
    }

    m = xadIOGetBitsLow(io, 16); /* number of blocks */
    j = 0; /* window position */
    while(m-- && !(io->xio_Flags & (XADIOF_ERROR|XADIOF_LASTOUTBYTE)))
    {
      /* these functions do not support access > 24 bit */
      xadIOGetBitsLow(io, 16); /* skip crunched block size */
      xadIOGetBitsLow(io, 16);
      n = xadIOGetBitsLow(io, 16); /* number of uncrunched bytes */
      n |= xadIOGetBitsLow(io, 16)<<16;
      SIT14_ReadTree(dat, 308, dat->var7);
      SIT14_ReadTree(dat, 75, dat->var3);

      while(n && !(io->xio_Flags & (XADIOF_ERROR|XADIOF_LASTOUTBYTE)))
      {
        for(i = 0; i < 616;)
          i = dat->var7[i + xadIOGetBitsLow(io, 1)];
        i -= 616;
        if(i < 0x100)
        {
          dat->Window[j++] = xadIOPutChar(io, i);
          j &= 0x3FFFF;
          --n;
        }
        else
        {
          i -= 0x100;
          k = dat->var2[i]+4;
          i = dat->var1[i];
          if(i)
            k += xadIOGetBitsLow(io, i);
          for(i = 0; i < 150;)
            i = dat->var3[i + xadIOGetBitsLow(io, 1)];
          i -= 150;
          l = dat->var5[i];
          i = dat->var4[i];
          if(i)
            l += xadIOGetBitsLow(io, i);
          n -= k;
          l = j+0x40000-l;
          while(k--)
          {
            l &= 0x3FFFF;
            dat->Window[j++] = xadIOPutChar(io, dat->Window[l++]);
            j &= 0x3FFFF;
          }
        }
      }
      xadIOByteBoundary(io);
    }
    xadFreeObjectA(XADM dat, 0);
  }
  return io->xio_Error;
}

/*****************************************************************************/

static const xadUINT16 SIT_rndtable[] = {
 0xee,  0x56,  0xf8,  0xc3,  0x9d,  0x9f,  0xae,  0x2c,
 0xad,  0xcd,  0x24,  0x9d,  0xa6, 0x101,  0x18,  0xb9,
 0xa1,  0x82,  0x75,  0xe9,  0x9f,  0x55,  0x66,  0x6a,
 0x86,  0x71,  0xdc,  0x84,  0x56,  0x96,  0x56,  0xa1,
 0x84,  0x78,  0xb7,  0x32,  0x6a,   0x3,  0xe3,   0x2,
 0x11, 0x101,   0x8,  0x44,  0x83, 0x100,  0x43,  0xe3,
 0x1c,  0xf0,  0x86,  0x6a,  0x6b,   0xf,   0x3,  0x2d,
 0x86,  0x17,  0x7b,  0x10,  0xf6,  0x80,  0x78,  0x7a,
 0xa1,  0xe1,  0xef,  0x8c,  0xf6,  0x87,  0x4b,  0xa7,
 0xe2,  0x77,  0xfa,  0xb8,  0x81,  0xee,  0x77,  0xc0,
 0x9d,  0x29,  0x20,  0x27,  0x71,  0x12,  0xe0,  0x6b,
 0xd1,  0x7c,   0xa,  0x89,  0x7d,  0x87,  0xc4, 0x101,
 0xc1,  0x31,  0xaf,  0x38,   0x3,  0x68,  0x1b,  0x76,
 0x79,  0x3f,  0xdb,  0xc7,  0x1b,  0x36,  0x7b,  0xe2,
 0x63,  0x81,  0xee,   0xc,  0x63,  0x8b,  0x78,  0x38,
 0x97,  0x9b,  0xd7,  0x8f,  0xdd,  0xf2,  0xa3,  0x77,
 0x8c,  0xc3,  0x39,  0x20,  0xb3,  0x12,  0x11,   0xe,
 0x17,  0x42,  0x80,  0x2c,  0xc4,  0x92,  0x59,  0xc8,
 0xdb,  0x40,  0x76,  0x64,  0xb4,  0x55,  0x1a,  0x9e,
 0xfe,  0x5f,   0x6,  0x3c,  0x41,  0xef,  0xd4,  0xaa,
 0x98,  0x29,  0xcd,  0x1f,   0x2,  0xa8,  0x87,  0xd2,
 0xa0,  0x93,  0x98,  0xef,   0xc,  0x43,  0xed,  0x9d,
 0xc2,  0xeb,  0x81,  0xe9,  0x64,  0x23,  0x68,  0x1e,
 0x25,  0x57,  0xde,  0x9a,  0xcf,  0x7f,  0xe5,  0xba,
 0x41,  0xea,  0xea,  0x36,  0x1a,  0x28,  0x79,  0x20,
 0x5e,  0x18,  0x4e,  0x7c,  0x8e,  0x58,  0x7a,  0xef,
 0x91,   0x2,  0x93,  0xbb,  0x56,  0xa1,  0x49,  0x1b,
 0x79,  0x92,  0xf3,  0x58,  0x4f,  0x52,  0x9c,   0x2,
 0x77,  0xaf,  0x2a,  0x8f,  0x49,  0xd0,  0x99,  0x4d,
 0x98, 0x101,  0x60,  0x93, 0x100,  0x75,  0x31,  0xce,
 0x49,  0x20,  0x56,  0x57,  0xe2,  0xf5,  0x26,  0x2b,
 0x8a,  0xbf,  0xde,  0xd0,  0x83,  0x34,  0xf4,  0x17
};

struct SIT_modelsym
{
  xadUINT16 sym;
  xadUINT32 cumfreq;
};

struct SIT_model
{
  xadINT32                increment;
  xadINT32                maxfreq;
  xadINT32                entries;
  xadUINT32               tabloc[256];
  struct SIT_modelsym *syms;
};

struct SIT_ArsenicData
{
  struct xadInOut *io;

  xadUINT16  csumaccum;
  xadUINT8 *window;
  xadUINT8 *windowpos;
  xadUINT8 *windowe;
  xadINT32   windowsize;
  xadINT32   tsize;
  xadUINT32  One;
  xadUINT32  Half;
  xadUINT32  Range;
  xadUINT32  Code;
  xadINT32   lastarithbits; /* init 0 */

  /* SIT_dounmntf function private */
  xadINT32   inited;        /* init 0 */
  xadUINT8  moveme[256];

  /* the private SIT_Arsenic function stuff */
  struct SIT_model initial_model;
  struct SIT_model selmodel;
  struct SIT_model mtfmodel[7];
  struct SIT_modelsym initial_syms[2+1];
  struct SIT_modelsym sel_syms[11+1];
  struct SIT_modelsym mtf0_syms[2+1];
  struct SIT_modelsym mtf1_syms[4+1];
  struct SIT_modelsym mtf2_syms[8+1];
  struct SIT_modelsym mtf3_syms[0x10+1];
  struct SIT_modelsym mtf4_syms[0x20+1];
  struct SIT_modelsym mtf5_syms[0x40+1];
  struct SIT_modelsym mtf6_syms[0x80+1];

  /* private for SIT_unblocksort */
  xadUINT32 counts[256];
  xadUINT32 cumcounts[256];
};

static void SIT_update_model(struct SIT_model *mymod, xadINT32 symindex)
{
  xadINT32 i;

  for (i = 0; i < symindex; i++)
    mymod->syms[i].cumfreq += mymod->increment;
  if(mymod->syms[0].cumfreq > mymod->maxfreq)
  {
    for(i = 0; i < mymod->entries ; i++)
    {
      /* no -1, want to include the 0 entry */
      /* this converts cumfreqs LONGo frequencies, then shifts right */
      mymod->syms[i].cumfreq -= mymod->syms[i+1].cumfreq;
      mymod->syms[i].cumfreq++; /* avoid losing things entirely */
      mymod->syms[i].cumfreq >>= 1;
    }
    /* then convert frequencies back to cumfreq */
    for(i = mymod->entries - 1; i >= 0; i--)
      mymod->syms[i].cumfreq += mymod->syms[i+1].cumfreq;
  }
}

static void SIT_getcode(struct SIT_ArsenicData *sa,
xadUINT32 symhigh, xadUINT32 symlow, xadUINT32 symtot) /* aka remove symbol */
{
  xadUINT32 lowincr;
  xadUINT32 renorm_factor;

  renorm_factor = sa->Range/symtot;
  lowincr = renorm_factor * symlow;
  sa->Code -= lowincr;
  if(symhigh == symtot)
    sa->Range -= lowincr;
  else
    sa->Range = (symhigh - symlow) * renorm_factor;

  sa->lastarithbits = 0;
  while(sa->Range <= sa->Half)
  {
    sa->Range <<= 1;
    sa->Code = (sa->Code << 1) | xadIOGetBitsHigh(sa->io, 1);
    sa->lastarithbits++;
  }
}

static xadINT32 SIT_getsym(struct SIT_ArsenicData *sa, struct SIT_model *model)
{
  xadINT32 freq;
  xadINT32 i;
  xadINT32 sym;

  /* getfreq */
  freq = sa->Code/(sa->Range/model->syms[0].cumfreq);
  for(i = 1; i < model->entries; i++)
  {
    if(model->syms[i].cumfreq <= freq)
      break;
  }
  sym = model->syms[i-1].sym;
  SIT_getcode(sa, model->syms[i-1].cumfreq, model->syms[i].cumfreq, model->syms[0].cumfreq);
  SIT_update_model(model, i);

  return sym;
}

static void SIT_reinit_model(struct SIT_model *mymod)
{
  xadINT32 cumfreq = mymod->entries * mymod->increment;
  xadINT32 i;

  for(i = 0; i <= mymod->entries; i++)
  {
    /* <= sets last frequency to 0; there isn't really a symbol for that
       last one  */
    mymod->syms[i].cumfreq = cumfreq;
    cumfreq -= mymod->increment;
  }
}

static void SIT_init_model(struct SIT_model *newmod, struct SIT_modelsym *sym,
xadINT32 entries, xadINT32 start, xadINT32 increment, xadINT32 maxfreq)
{
  xadINT32 i;

  newmod->syms = sym;
  newmod->increment = increment;
  newmod->maxfreq = maxfreq;
  newmod->entries = entries;
  /* memset(newmod->tabloc, 0, sizeof(newmod->tabloc)); */
  for(i = 0; i < entries; i++)
  {
    newmod->tabloc[(entries - i - 1) + start] = i;
    newmod->syms[i].sym = (entries - i - 1) + start;
  }
  SIT_reinit_model(newmod);
}

static xadUINT32 SIT_arith_getbits(struct SIT_ArsenicData *sa, struct SIT_model *model, xadINT32 nbits)
{
  /* the model is assumed to be a binary one */
  xadUINT32 addme = 1;
  xadUINT32 accum = 0;
  while(nbits--)
  {
    if(SIT_getsym(sa, model))
      accum += addme;
    addme += addme;
  }
  return accum;
}

static xadINT32 SIT_dounmtf(struct SIT_ArsenicData *sa, xadINT32 sym)
{
  xadINT32 i;
  xadINT32 result;

  if(sym == -1 || !sa->inited)
  {
    for(i = 0; i < 256; i++)
      sa->moveme[i] = i;
    sa->inited = 1;
  }
  if(sym == -1)
    return 0;
  result = sa->moveme[sym];
  for(i = sym; i > 0 ; i-- )
    sa->moveme[i] = sa->moveme[i-1];

  sa->moveme[0] = result;
  return result;
}

static xadINT32 SIT_unblocksort(struct SIT_ArsenicData *sa, xadUINT8 *block,
xadUINT32 blocklen, xadUINT32 last_index, xadUINT8 *outblock)
{
  xadUINT32 i, j;
  xadUINT32 *xform;
  xadUINT8 *blockptr;
  xadUINT32 cum;
  //struct xadMasterBase *xadMasterBase = sa->io->xio_xadMasterBase;

  memset(sa->counts, 0, sizeof(sa->counts));
  if((xform = xadAllocVec(XADM sizeof(xadUINT32)*blocklen, XADMEMF_ANY)))
  {
    blockptr = block;
    for(i = 0; i < blocklen; i++)
      sa->counts[*blockptr++]++;

    cum = 0;
    for(i = 0; i < 256; i++)
    {
      sa->cumcounts[i] = cum;
      cum += sa->counts[i];
      sa->counts[i] = 0;
    }

    blockptr = block;
    for(i = 0; i < blocklen; i++)
    {
      xform[sa->cumcounts[*blockptr] + sa->counts[*blockptr]] = i;
      sa->counts[*blockptr++]++;
    }

    blockptr = outblock;
    for(i = 0, j = xform[last_index]; i < blocklen; i++, j = xform[j])
    {
      *blockptr++ = block[j];
//      block[j] = 0xa5; /* for debugging */
    }
    xadFreeObjectA(XADM xform, 0);
  }
  else
    return XADERR_NOMEMORY;
  return 0;
}

static void SIT_write_and_unrle_and_unrnd(struct xadInOut *io, xadUINT8 *block, xadUINT32 blocklen, xadINT16 rnd)
{
  xadINT32 count = 0;
  xadINT32 last = 0;
  xadUINT8 *blockptr = block;
  xadUINT32 i;
  xadUINT32 j;
  xadINT32 ch;
  xadINT32 rndindex;
  xadINT32 rndcount;

  rndindex = 0;
  rndcount = SIT_rndtable[rndindex];
  for(i = 0; i < blocklen; i++)
  {
    ch = *blockptr++;
    if(rnd && (rndcount == 0))
    {
      ch ^= 1;
      rndindex++;
      if (rndindex == sizeof(SIT_rndtable)/sizeof(SIT_rndtable[0]))
        rndindex = 0;
      rndcount = SIT_rndtable[rndindex];
    }
    rndcount--;

    if(count == 4)
    {
      for(j = 0; j < ch; j++)
        xadIOPutChar(io, last);
      count = 0;
    }
    else
    {
      xadIOPutChar(io, ch);
      if(ch != last)
      {
        count = 0;
        last = ch;
      }
      count++;
    }
  }
}

static xadINT32 SIT_Arsenic(struct xadInOut *io)
{
  xadINT32 err = 0;
  struct SIT_ArsenicData *sa;
  //struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;

  io->xio_Flags &= ~(XADIOF_NOCRC32);
  io->xio_Flags |= XADIOF_NOCRC16;
  io->xio_CRC32 = ~0;

  if((sa = (struct SIT_ArsenicData *) xadAllocVec(XADM sizeof(struct SIT_ArsenicData), XADMEMF_ANY|XADMEMF_CLEAR)))
  {
    xadINT32 i, sym, sel;
    xadINT16 blockbits;
    xadUINT32 w, blocksize;
    xadINT32 stopme, nchars; /* 32 bits */
    xadINT32 repeatstate, repeatcount;
    xadINT32 primary_index; /* 32 bits */
    xadINT32 eob, rnd;
    xadUINT8 *block, *blockptr, *unsortedblock;

    sa->io = io;
    sa->Range = sa->One = 1<<25;
    sa->Half = 1<<24;
    sa->Code = xadIOGetBitsHigh(io, 26);

    SIT_init_model(&sa->initial_model, sa->initial_syms, 2, 0, 1, 256);
    SIT_init_model(&sa->selmodel, sa->sel_syms, 11, 0, 8, 1024);
    /* selector model: 11 selections, starting at 0, 8 increment, 1024 maxfreq */

    SIT_init_model(&sa->mtfmodel[0], sa->mtf0_syms, 2, 2, 8, 1024);
    /* model 3: 2 symbols, starting at 2, 8 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[1], sa->mtf1_syms, 4, 4, 4, 1024);
    /* model 4: 4 symbols, starting at 4, 4 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[2], sa->mtf2_syms, 8, 8, 4, 1024);
    /* model 5: 8 symbols, starting at 8, 4 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[3], sa->mtf3_syms, 0x10, 0x10, 4, 1024);
    /* model 6: $10 symbols, starting at $10, 4 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[4], sa->mtf4_syms, 0x20, 0x20, 2, 1024);
    /* model 7: $20 symbols, starting at $20, 2 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[5], sa->mtf5_syms, 0x40, 0x40, 2, 1024);
    /* model 8: $40 symbols, starting at $40, 2 increment, 1024 maxfreq */
    SIT_init_model(&sa->mtfmodel[6], sa->mtf6_syms, 0x80, 0x80, 1, 1024);
    /* model 9: $80 symbols, starting at $80, 1 increment, 1024 maxfreq */
    if(SIT_arith_getbits(sa, &sa->initial_model, 8) != 0x41 ||
    SIT_arith_getbits(sa, &sa->initial_model, 8) != 0x73)
      err = XADERR_ILLEGALDATA;
    w = SIT_arith_getbits(sa, &sa->initial_model, 4);
    blockbits = w + 9;
    blocksize = 1<<blockbits;
    if(!err)
    {
      if((block = xadAllocVec(XADM blocksize, XADMEMF_ANY)))
      {
        if((unsortedblock = xadAllocVec(XADM blocksize, XADMEMF_ANY)))
        {
          eob = SIT_getsym(sa, &sa->initial_model);
          while(!eob && !err)
          {
            rnd = SIT_getsym(sa, &sa->initial_model);
            primary_index = SIT_arith_getbits(sa, &sa->initial_model, blockbits);
            nchars = stopme = repeatstate = repeatcount = 0;
            blockptr = block;
            while(!stopme)
            {
              sel = SIT_getsym(sa, &sa->selmodel);
              switch(sel)
              {
              case 0:
                sym = -1;
                if(!repeatstate)
                  repeatstate = repeatcount = 1;
                else
                {
                  repeatstate += repeatstate;
                  repeatcount += repeatstate;
                }
                break;
              case 1:
                if(!repeatstate)
                {
                  repeatstate = 1;
                  repeatcount = 2;
                }
                else
                {
                  repeatstate += repeatstate;
                  repeatcount += repeatstate;
                  repeatcount += repeatstate;
                }
                sym = -1;
                break;
              case 2:
                sym = 1;
                break;
              case 10:
                stopme = 1;
                sym = 0;
                break;
              default:
                if((sel > 9) || (sel < 3))
                { /* this basically can't happen */
                  err = XADERR_ILLEGALDATA;
                  stopme = 1;
                  sym = 0;
                }
                else
                  sym = SIT_getsym(sa, &sa->mtfmodel[sel-3]);
                break;
              }
              if(repeatstate && (sym >= 0))
              {
                nchars += repeatcount;
                repeatstate = 0;
                memset(blockptr, SIT_dounmtf(sa, 0), repeatcount);
                blockptr += repeatcount;
                repeatcount = 0;
              }
              if(!stopme && !repeatstate)
              {
                sym = SIT_dounmtf(sa, sym);
                *blockptr++ = sym;
                nchars++;
              }
              if(nchars > blocksize)
              {
                err = XADERR_ILLEGALDATA;
                stopme = 1;
              }
            }
            if(err)
              break;
            if((err = SIT_unblocksort(sa, block, nchars, primary_index, unsortedblock)))
              break;
            SIT_write_and_unrle_and_unrnd(io, unsortedblock, nchars, rnd);
            eob = SIT_getsym(sa, &sa->initial_model);
            SIT_reinit_model(&sa->selmodel);
            for(i = 0; i < 7; i ++)
              SIT_reinit_model(&sa->mtfmodel[i]);
            SIT_dounmtf(sa, -1);
          }
          if(!err)
          {
            err = xadIOWriteBuf(io);
            if(!err && SIT_arith_getbits(sa, &sa->initial_model, 32) != ~io->xio_CRC32)
              err = XADERR_CHECKSUM;
          }
          xadFreeObjectA(XADM unsortedblock, 0);
        }
        else
          err = XADERR_NOMEMORY;
        xadFreeObjectA(XADM block, 0);
      }
      else
        err = XADERR_NOMEMORY;
    } /* if(!err) */
    xadFreeObjectA(XADM sa, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}








@implementation XADStuffItLZAHHandle

-(xadINT32)unpackData
{
	return SIT_lzah([self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32]);
}

@end

@implementation XADStuffItMWHandle

-(xadINT32)unpackData
{
	return SIT_mw([self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32]);
}

@end

@implementation XADStuffItOld13Handle

-(xadINT32)unpackData
{
	return SIT_13([self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32|XADIOF_NOINENDERR]);
}

@end

@implementation XADStuffIt14Handle

-(xadINT32)unpackData
{
	return SIT_14([self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32]);
}
@end

@implementation XADStuffItOldArsenicHandle

-(xadINT32)unpackData
{
	return SIT_Arsenic([self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32]);
}

@end

