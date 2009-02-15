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

@implementation XADStuffIt14Handle

-(xadINT32)unpackData
{
	return SIT_14([self ioStructWithFlags:XADIOF_ALLOCINBUFFER|XADIOF_ALLOCOUTBUFFER|XADIOF_NOCRC32]);
}
@end

