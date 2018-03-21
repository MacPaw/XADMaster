/*
 * XADARJFastestHandle.m
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
#import "XADARJFastestHandle.h"

@implementation XADARJFastestHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [super initWithInputBufferForHandle:handle length:length windowSize:0x8000];
}

-(void)resetLZSSHandle
{
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	int val=0;
	int pow=0;
	while(pow<7)
	{
		if(!CSInputNextBit(input)) break;
		val+=1<<pow;
		pow++;
	}
	if(pow) val+=CSInputNextBitString(input,pow);

	if(!val) return CSInputNextBitString(input,8);
	else
	{
		int offs=0;
		int pow=9;
		while(pow<13)
		{
			if(!CSInputNextBit(input)) break;
			offs+=1<<pow;
			pow++;
		}
		offs+=CSInputNextBitString(input,pow);

		*offset=offs+1;
		*length=val+2;

		return XADLZSSMatch;
	}
}

@end

/*

#define ARJSTRTP         9
#define ARJSTOPP        13

#define ARJSTRTL         0
#define ARJSTOPL         7

static xadINT32 ARJ_Decrunch(struct xadInOut *io)
{
  struct xadMasterBase *xadMasterBase = io->xio_xadMasterBase;
  xadINT32 err;
  xadUINT32 dicsiz = (1<<15);
  xadSTRPTR text;
  xadINT16 i, c, width, pwr;
  xadUINT32 loc = 0;

  if((text = xadAllocVec(XADM dicsiz, XADMEMF_PUBLIC|XADMEMF_CLEAR)))
  {
    --dicsiz;
    while(!(io->xio_Flags & (XADIOF_LASTOUTBYTE|XADIOF_ERROR)))
    {
      c = 0;
      pwr = 1 << (ARJSTRTL);
      for(width = (ARJSTRTL); width < (ARJSTOPL); width++)
      {
        if(!xadIOGetBitsHigh(io, 1))
          break;
        c += pwr;
        pwr <<= 1;
      }
      if(width)
        c += xadIOGetBitsHigh(io, width);

      if(!c)
      {
        text[loc++] = xadIOPutChar(io, xadIOGetBitsHigh(io, 8));
        loc &= dicsiz;
      }
      else
      {
        c += 3 - 1;

        i = 0;
        pwr = 1 << (ARJSTRTP);
        for(width = (ARJSTRTP); width < (ARJSTOPP); width++)
        {
          if(!xadIOGetBitsHigh(io, 1))
            break;
          i += pwr;
          pwr <<= 1;
        }
        if(width)
          i += xadIOGetBitsHigh(io, width);
        i = loc - i - 1;
        while(c--)
        {
          text[loc++] = xadIOPutChar(io, text[i++ & dicsiz]);
          loc &= dicsiz;
        }
      }
    }
    err = io->xio_Error;
    xadFreeObjectA(XADM text, 0);
  }
  else
    err = XADERR_NOMEMORY;

  return err;
}
*/
