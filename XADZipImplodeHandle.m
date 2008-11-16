#import "XADZipImplodeHandle.h"
#import "XADException.h"

#import "CSMemoryHandle.h"


@implementation XADZipImplodeHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
largeDictionary:(BOOL)largedict literalTree:(BOOL)hasliterals
{
	if(self=[super initWithHandle:handle length:length])
	{
		if(largedict)
		{
			dictionarywindow=malloc(8192);
			dictionarymask=8191;
			offsetbits=7;
		}
		else
		{
			dictionarywindow=malloc(4096);
			dictionarymask=4095;
			offsetbits=6;
		}

		literaltree=lengthtree=offsettree=nil;

		@try
		{
			if(hasliterals) literaltree=[[self parseImplodeTreeOfSize:256 handle:handle] retain];
			lengthtree=[[self parseImplodeTreeOfSize:64 handle:handle] retain];
			offsettree=[[self parseImplodeTreeOfSize:64 handle:handle] retain];
		} @catch(id e) {
			NSLog(@"Error parsing prefix trees for implode algorithm: %@",e);
			[self release];
			return nil;
		}

		[self setParentStartOffset:[handle offsetInFile]];
	}
	return self;
}

-(void)dealloc
{
	free(dictionarywindow);
	[literaltree release];
	[lengthtree release];
	[offsettree release];
	[super dealloc];
}

-(XADPrefixTree *)parseImplodeTreeOfSize:(int)size handle:(CSHandle *)fh
{
	int numgroups=[fh readUInt8]+1;

	int codelength[numgroups];
	int numcodes[numgroups];
	int valuestart[numgroups];
	int totalcodes=0;

	for(int i=0;i<numgroups;i++)
	{
		int val=[fh readUInt8];

		codelength[i]=(val&0x0f)+1;
		numcodes[i]=(val>>4)+1;
		valuestart[i]=totalcodes;
//NSLog(@"len %d,num %d, start %d",codelength[i],numcodes[i],valuestart[i]);
		totalcodes+=numcodes[i];
	}

	if(totalcodes!=size) [XADException raiseIllegalDataException];

	XADPrefixTree *tree=[XADPrefixTree prefixTree];

	int prevlength=17;
	int code=0;

	for(int length=16;length>=1;length--)
	for(int n=numgroups-1;n>=0;n--)
	{
		if(codelength[n]!=length) continue;

		int num=numcodes[n];
		int start=valuestart[n];

		for(int j=num-1;j>=0;j--)
		{
//NSLog(@"-->%d: %x %d",start+j,code,length);
			[tree addValue:start+j forCode:code>>16-length length:length];
			code+=1<<16-length;
		}

		prevlength=length;
	}

	return tree;
}

-(void)resetFilter
{
	dictionarylen=0;
	dictionaryoffs=0;
	memset(dictionarywindow,0,dictionarymask+1);

	CSFilterStartReadingBitsLE(self);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!dictionarylen)
	{
		int bit=CSFilterNextBitLE(self);
		if(bit)
		{
			uint8_t byte;
			if(literaltree) byte=CSFilterNextSymbolFromTreeLE(self,literaltree);
			else byte=CSFilterNextBitStringLE(self,8);

			return dictionarywindow[pos&dictionarymask]=byte;
		}
		else
		{
			int offset=CSFilterNextBitStringLE(self,offsetbits);
			offset|=CSFilterNextSymbolFromTreeLE(self,offsettree)<<offsetbits;

			dictionaryoffs=pos-offset-1;

			dictionarylen=CSFilterNextSymbolFromTreeLE(self,lengthtree)+2;
			if(dictionarylen==65) dictionarylen+=CSFilterNextBitStringLE(self,8);
			if(literaltree) dictionarylen++;
		}
	}

	dictionarylen--;
	uint8_t byte=dictionarywindow[dictionaryoffs++&dictionarymask];

	return dictionarywindow[pos&dictionarymask]=byte;
}

@end

#if 0

/* Tables for length and distance */
static const xadUINT16 Zipcplen2[] = {2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
  18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34,
  35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51,
  52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65};
static const xadUINT16 Zipcplen3[] = {3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18,
  19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
  36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52,
  53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66};
static const xadUINT16 Zipextra[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  8};
static const xadUINT16 Zipcpdist4[] = {1, 65, 129, 193, 257, 321, 385, 449, 513, 577, 641, 705,
  769, 833, 897, 961, 1025, 1089, 1153, 1217, 1281, 1345, 1409, 1473,
  1537, 1601, 1665, 1729, 1793, 1857, 1921, 1985, 2049, 2113, 2177,
  2241, 2305, 2369, 2433, 2497, 2561, 2625, 2689, 2753, 2817, 2881,
  2945, 3009, 3073, 3137, 3201, 3265, 3329, 3393, 3457, 3521, 3585,
  3649, 3713, 3777, 3841, 3905, 3969, 4033};
static const xadUINT16 Zipcpdist8[] = {1, 129, 257, 385, 513, 641, 769, 897, 1025, 1153, 1281,
  1409, 1537, 1665, 1793, 1921, 2049, 2177, 2305, 2433, 2561, 2689,
  2817, 2945, 3073, 3201, 3329, 3457, 3585, 3713, 3841, 3969, 4097,
  4225, 4353, 4481, 4609, 4737, 4865, 4993, 5121, 5249, 5377, 5505,
  5633, 5761, 5889, 6017, 6145, 6273, 6401, 6529, 6657, 6785, 6913,
  7041, 7169, 7297, 7425, 7553, 7681, 7809, 7937, 8065};

static xadINT32 Zipget_tree(struct ZipData *zd, xadUINT32 *l, xadUINT32 n)
{
  xadUINT32 i;           /* bytes remaining in list */
  xadUINT32 k;           /* lengths entered */
  xadUINT32 j;           /* number of codes */
  xadUINT32 b;           /* bit length for those codes */

  /* get bit lengths */
  i = Zipgetbyte(zd) + 1;                     /* length/count pairs to read */
  k = 0;                                /* next code */
  do {
    b = ((j = Zipgetbyte(zd)) & 0xf) + 1;     /* bits in code (1..16) */
    j = ((j & 0xf0) >> 4) + 1;          /* codes with those bits (1..16) */
    if(k + j > n)
      return 4;                         /* don't overflow l[] */
    do {
      l[k++] = b;
    } while(--j);
  } while(--i);
  return k != n ? 4 : 0;                /* should have read n of them */
}

static void Zipexplode_lit8(struct ZipData *zd, struct Ziphuft *tb, struct Ziphuft *tl, struct Ziphuft *td, xadINT32 bb, xadINT32 bl, xadINT32 bd)
{
  xadINT32 s;               /* bytes to decompress */
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct Ziphuft *t;       /* pointer to table entry */
  xadUINT32 mb, ml, md;  /* masks for bb, bl, and bd bits */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */
  xadUINT32 u;           /* true if unflushed */

  /* Zipexplode the coded data */
  b = k = w = 0;                /* initialize bit buffer, window */
  u = 1;                        /* buffer unflushed */
  mb = Zipmask[bb];           /* precompute masks for speed */
  ml = Zipmask[bl];
  md = Zipmask[bd];
  s = zd->ucsize;
  while(s > 0)                 /* do until zd->ucsize bytes uncompressed */
  {
    ZIPNEEDBITS(1)
    if(b & 1)                  /* then literal--decode it */
    {
      ZIPDUMPBITS(1)
      s--;
      ZIPNEEDBITS((xadUINT32)bb)    /* get coded literal */
      if((e = (t = tb + ((~(xadUINT32)b) & mb))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      zd->Slide[w++] = (xadUINT8)t->v.n;
      if(w == ZIPWSIZE)
      {
        Zipflush(zd, w);
        w = u = 0;
      }
    }
    else                        /* else distance/length */
    {
      ZIPDUMPBITS(1)
      ZIPNEEDBITS(7)               /* get distance low bits */
      d = (xadUINT32)b & 0x7f;
      ZIPDUMPBITS(7)
      ZIPNEEDBITS((xadUINT32)bd)    /* get coded distance high bits */
      if((e = (t = td + ((~(xadUINT32)b) & md))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      d = w - d - t->v.n;       /* construct offset */
      ZIPNEEDBITS((xadUINT32)bl)    /* get coded length */
      if((e = (t = tl + ((~(xadUINT32)b) & ml))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      n = t->v.n;
      if(e)                    /* get length extra bits */
      {
        ZIPNEEDBITS(8)
        n += (xadUINT32)b & 0xff;
        ZIPDUMPBITS(8)
      }

      /* do the copy */
      s -= n;
      do {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        if(u && w <= d)
        {
          memset(zd->Slide + w, 0, e);
          w += e;
          d += e;
        }
        else /* or use xadCopyMem */
            do {
              zd->Slide[w++] = zd->Slide[d++];
            } while(--e);
        if(w == ZIPWSIZE)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      } while(n);
    }
  }

  Zipflush(zd, w);
}

static void Zipexplode_lit4(struct ZipData *zd, struct Ziphuft *tb,
struct Ziphuft *tl, struct Ziphuft *td, xadINT32 bb, xadINT32 bl, xadINT32 bd)
{
  xadINT32 s;               /* bytes to decompress */
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct Ziphuft *t;       /* pointer to table entry */
  xadUINT32 mb, ml, md;  /* masks for bb, bl, and bd bits */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */
  xadUINT32 u;           /* true if unflushed */

  /* Zipexplode the coded data */
  b = k = w = 0;                /* initialize bit buffer, window */
  u = 1;                        /* buffer unflushed */
  mb = Zipmask[bb];           /* precompute masks for speed */
  ml = Zipmask[bl];
  md = Zipmask[bd];
  s = zd->ucsize;
  while(s > 0)                 /* do until zd->ucsize bytes uncompressed */
  {
    ZIPNEEDBITS(1)
    if(b & 1)                  /* then literal--decode it */
    {
      ZIPDUMPBITS(1)
      s--;
      ZIPNEEDBITS((xadUINT32)bb)    /* get coded literal */
      if((e = (t = tb + ((~(xadUINT32)b) & mb))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      zd->Slide[w++] = (xadUINT8)t->v.n;
      if(w == ZIPWSIZE)
      {
        Zipflush(zd, w);
        w = u = 0;
      }
    }
    else                        /* else distance/length */
    {
      ZIPDUMPBITS(1)
      ZIPNEEDBITS(6)               /* get distance low bits */
      d = (xadUINT32)b & 0x3f;
      ZIPDUMPBITS(6)
      ZIPNEEDBITS((xadUINT32)bd)    /* get coded distance high bits */
      if((e = (t = td + ((~(xadUINT32)b) & md))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      d = w - d - t->v.n;       /* construct offset */
      ZIPNEEDBITS((xadUINT32)bl)    /* get coded length */
      if((e = (t = tl + ((~(xadUINT32)b) & ml))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      n = t->v.n;
      if(e)                    /* get length extra bits */
      {
        ZIPNEEDBITS(8)
        n += (xadUINT32)b & 0xff;
        ZIPDUMPBITS(8)
      }

      /* do the copy */
      s -= n;
      do {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        if(u && w <= d)
        {
          memset(zd->Slide + w, 0, e);
          w += e;
          d += e;
        }
        else /* or use xadCopyMem */
            do {
              zd->Slide[w++] = zd->Slide[d++];
            } while(--e);
        if(w == ZIPWSIZE)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      } while(n);
    }
  }

  Zipflush(zd, w);
}

static void Zipexplode_nolit8(struct ZipData *zd, struct Ziphuft *tl,
struct Ziphuft *td, xadINT32 bl, xadINT32 bd)
{
  xadINT32 s;               /* bytes to decompress */
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct Ziphuft *t;       /* pointer to table entry */
  xadUINT32 ml, md;      /* masks for bl and bd bits */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */
  xadUINT32 u;           /* true if unflushed */

  /* Zipexplode the coded data */
  b = k = w = 0;                /* initialize bit buffer, window */
  u = 1;                        /* buffer unflushed */
  ml = Zipmask[bl];           /* precompute masks for speed */
  md = Zipmask[bd];
  s = zd->ucsize;
  while(s > 0)                 /* do until zd->ucsize bytes uncompressed */
  {
    ZIPNEEDBITS(1)
    if(b & 1)                  /* then literal--get eight bits */
    {
      ZIPDUMPBITS(1)
      s--;
      ZIPNEEDBITS(8)
      zd->Slide[w++] = (xadUINT8)b;
      if(w == ZIPWSIZE)
      {
        Zipflush(zd, w);
        w = u = 0;
      }
      ZIPDUMPBITS(8)
    }
    else                        /* else distance/length */
    {
      ZIPDUMPBITS(1)
      ZIPNEEDBITS(7)               /* get distance low bits */
      d = (xadUINT32)b & 0x7f;
      ZIPDUMPBITS(7)
      ZIPNEEDBITS((xadUINT32)bd)    /* get coded distance high bits */
      if((e = (t = td + ((~(xadUINT32)b) & md))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      d = w - d - t->v.n;       /* construct offset */
      ZIPNEEDBITS((xadUINT32)bl)    /* get coded length */
      if((e = (t = tl + ((~(xadUINT32)b) & ml))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      n = t->v.n;
      if(e)                    /* get length extra bits */
      {
        ZIPNEEDBITS(8)
        n += (xadUINT32)b & 0xff;
        ZIPDUMPBITS(8)
      }

      /* do the copy */
      s -= n;
      do {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        if(u && w <= d)
        {
          memset(zd->Slide + w, 0, e);
          w += e;
          d += e;
        }
        else /* or use xadCopyMem */
            do {
              zd->Slide[w++] = zd->Slide[d++];
            } while(--e);
        if(w == ZIPWSIZE)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      } while(n);
    }
  }

  Zipflush(zd, w);
}

static void Zipexplode_nolit4(struct ZipData *zd, struct Ziphuft *tl,
struct Ziphuft *td, xadUINT32 bl, xadUINT32 bd)
{
  xadINT32 s;               /* bytes to decompress */
  register xadUINT32 e;  /* table entry flag/number of extra bits */
  xadUINT32 n, d;        /* length and index for copy */
  xadUINT32 w;           /* current window position */
  struct Ziphuft *t;       /* pointer to table entry */
  xadUINT32 ml, md;      /* masks for bl and bd bits */
  register xadUINT32 b;       /* bit buffer */
  register xadUINT32 k;  /* number of bits in bit buffer */
  xadUINT32 u;           /* true if unflushed */

  /* Zipexplode the coded data */
  b = k = w = 0;                /* initialize bit buffer, window */
  u = 1;                        /* buffer unflushed */
  ml = Zipmask[bl];           /* precompute masks for speed */
  md = Zipmask[bd];
  s = zd->ucsize;
  while(s > 0)                 /* do until zd->ucsize bytes uncompressed */
  {
    ZIPNEEDBITS(1)
    if(b & 1)                  /* then literal--get eight bits */
    {
      ZIPDUMPBITS(1)
      s--;
      ZIPNEEDBITS(8)
      zd->Slide[w++] = (xadUINT8)b;
      if(w == ZIPWSIZE)
      {
        Zipflush(zd, w);
        w = u = 0;
      }
      ZIPDUMPBITS(8)
    }
    else                        /* else distance/length */
    {
      ZIPDUMPBITS(1)
      ZIPNEEDBITS(6)               /* get distance low bits */
      d = (xadUINT32)b & 0x3f;
      ZIPDUMPBITS(6)
      ZIPNEEDBITS((xadUINT32)bd)    /* get coded distance high bits */
      if((e = (t = td + ((~(xadUINT32)b) & md))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      d = w - d - t->v.n;       /* construct offset */
      ZIPNEEDBITS((xadUINT32)bl)    /* get coded length */
      if((e = (t = tl + ((~(xadUINT32)b) & ml))->e) > 16)
        do {
          if(e == 99)
            return;
          ZIPDUMPBITS(t->b)
          e -= 16;
          ZIPNEEDBITS(e)
        } while((e = (t = t->v.t + ((~(xadUINT32)b) & Zipmask[e]))->e) > 16);
      ZIPDUMPBITS(t->b)
      n = t->v.n;
      if(e)                    /* get length extra bits */
      {
        ZIPNEEDBITS(8)
        n += (xadUINT32)b & 0xff;
        ZIPDUMPBITS(8)
      }

      /* do the copy */
      s -= n;
      do {
        n -= (e = (e = ZIPWSIZE - ((d &= ZIPWSIZE-1) > w ? d : w)) > n ? n : e);
        if(u && w <= d)
        {
          memset(zd->Slide + w, 0, e);
          w += e;
          d += e;
        }
        else /* or use xadCopyMem */
            do {
              zd->Slide[w++] = zd->Slide[d++];
            } while(--e);
        if(w == ZIPWSIZE)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      } while(n);
    }
  }

  Zipflush(zd, w);
}

static void Zipexplode(struct ZipData *zd)
{
  xadUINT32 r;           /* return codes */
  struct Ziphuft *tb;      /* literal code table */
  struct Ziphuft *tl;      /* length code table */
  struct Ziphuft *td;      /* distance code table */
  xadINT32 bb;               /* bits for tb */
  xadINT32 bl;               /* bits for tl */
  xadINT32 bd;               /* bits for td */
  xadUINT32 *l;          /* bit lengths for codes */

  l = zd->ll;
  /* Tune base table sizes.  Note: I thought that to truly optimize speed,
     I would have to select different bl, bd, and bb values for different
     compressed file sizes.  I was suprised to find out the the values of
     7, 7, and 9 worked best over a very wide range of sizes, except that
     bd = 8 worked marginally better for large compressed sizes. */
  bl = 7;
  bd = zd->csize > 200000L ? 8 : 7;

  /* With literal tree--minimum match length is 3 */
  if(zd->Flags & 4)
  {
    bb = 9;                     /* base table size for literals */
    if(Zipget_tree(zd,l, 256))
      return;
    if((r = Ziphuft_build(zd, l, 256, 256, NULL, NULL, &tb, &bb)))
    {
      if(r == 1)
        Ziphuft_free(zd, tb);
      return;
    }
    if(Zipget_tree(zd,l, 64))
      return;
    if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcplen3,
    (xadUINT16 *) Zipextra, &tl, &bl)))
    {
      if(r == 1)
        Ziphuft_free(zd, tl);
      Ziphuft_free(zd, tb);
      return;
    }
    if(Zipget_tree(zd,l, 64))
      return;
    if(zd->Flags & 2)      /* true if 8K */
    {
      if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcpdist8,
      (xadUINT16 *) Zipextra, &td, &bd)))
      {
        if(r == 1)
          Ziphuft_free(zd, td);
        Ziphuft_free(zd, tl);
        Ziphuft_free(zd, tb);
        return;
      }
      Zipexplode_lit8(zd, tb, tl, td, bb, bl, bd);
    }
    else                                        /* else 4K */
    {
      if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcpdist4, (xadUINT16 *) Zipextra, &td, &bd)))
      {
        if(r == 1)
          Ziphuft_free(zd, td);
        Ziphuft_free(zd, tl);
        Ziphuft_free(zd, tb);
        return ;
      }
      Zipexplode_lit4(zd, tb, tl, td, bb, bl, bd);
    }
    Ziphuft_free(zd, td);
    Ziphuft_free(zd, tl);
    Ziphuft_free(zd, tb);
  }
  else /* No literal tree--minimum match length is 2 */
  {
    if(Zipget_tree(zd,l, 64))
      return;
    if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcplen2, (xadUINT16 *) Zipextra, &tl, &bl)))
    {
      if(r == 1)
        Ziphuft_free(zd, tl);
      return;
    }
    if((r = Zipget_tree(zd,l, 64)))
      return;
    if(zd->Flags & 2)      /* true if 8K */
    {
      if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcpdist8, (xadUINT16 *) Zipextra, &td, &bd)))
      {
        if(r == 1)
          Ziphuft_free(zd, td);
        Ziphuft_free(zd, tl);
        return;
      }
      Zipexplode_nolit8(zd, tl, td, bl, bd);
    }
    else                                        /* else 4K */
    {
      if((r = Ziphuft_build(zd, l, 64, 0, (xadUINT16 *) Zipcpdist4, (xadUINT16 *) Zipextra, &td, &bd)))
      {
        if(r == 1)
          Ziphuft_free(zd, td);
        Ziphuft_free(zd, tl);
        return;
      }
      Zipexplode_nolit4(zd, tl, td, (xadUINT32) bl, (xadUINT32) bd);
    }
    Ziphuft_free(zd, td);
    Ziphuft_free(zd, tl);
  }
}











/**************************************************************************************************/

#define ZIPDLE    144
typedef xadUINT8 Zipf_array[64];        /* for followers[256][64] */

static const xadUINT8 ZipL_table[] = {0, 0x7f, 0x3f, 0x1f, 0x0f};
static const xadUINT8 ZipD_shift[] = {0, 0x07, 0x06, 0x05, 0x04};
static const xadUINT8 ZipB_table[] = {
 8, 1, 1, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 5,
 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6,
 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 7,
 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
 8, 8, 8, 8
};

static void Zipunreduce(struct ZipData *zd, xadINT32 factor)   /* expand probabilistically reduced data */
{
  register xadINT32 lchar = 0;
  xadINT32 nchar, ExState = 0, V = 0, Len = 0;
  xadINT32 s = zd->ucsize;  /* number of bytes left to decompress */
  xadUINT32 w = 0;      /* position in output window slide[] */
  xadUINT32 u = 1;      /* true if slide[] unflushed */
  xadUINT32 zipeof = 0, bits_left = 0, bitbuf = 0;
  xadUINT8 *Slen, *slide;
  Zipf_array *followers;     /* shared work space */

  Slen = zd->Stack;
  slide = zd->Slide;
  followers = (Zipf_array *)(zd->Slide + 0x4000);
  --factor; /* factor is compression method - 1 */

  {
    register xadINT32 x;
    register xadINT32 i;

    for(x = 255; x >= 0; x--)
    {
       ZIPREADBITS(6, Slen[x])   /* ; */
       for(i = 0; (xadUINT8)i < Slen[x]; i++)
         ZIPREADBITS(8, followers[x][i])   /* ; */
    }
  }

  while(s > 0 && !zipeof)
  {
    if(Slen[lchar] == 0)
      ZIPREADBITS(8, nchar)   /* ; */
    else
    {
      ZIPREADBITS(1, nchar)   /* ; */
      if(nchar != 0)
        ZIPREADBITS(8, nchar)       /* ; */
      else
      {
        xadINT32 follower;
        xadINT32 bitsneeded = ZipB_table[Slen[lchar]];

        ZIPREADBITS(bitsneeded, follower)   /* ; */
        nchar = followers[lchar][follower];
      }
    }
    /* expand the resulting byte */
    switch(ExState)
    {
    case 0:
      if(nchar != ZIPDLE)
      {
        s--;
        slide[w++] = (xadUINT8)nchar;
        if(w == 0x4000)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
      }
      else
        ExState = 1;
      break;
    case 1:
      if(nchar != 0)
      {
        V = nchar;
        Len = V & ZipL_table[factor];
        if(Len == ZipL_table[factor])
          ExState = 2;
        else
          ExState = 3;
      }
      else
      {
        s--;
        slide[w++] = ZIPDLE;
        if(w == 0x4000)
        {
          Zipflush(zd, w);
          w = u = 0;
        }
        ExState = 0;
      }
      break;
    case 2:
      Len += nchar;
      ExState = 3;
      break;
    case 3:
      {
        register xadUINT32 e, n = Len + 3, d = w - ((((V >> ZipD_shift[factor]) & Zipmask[factor]) << 8) + nchar + 1);

        s -= n;
        do
        {
          n -= (e = (e = 0x4000 - ((d &= 0x3fff) > w ? d : w)) > n ? n : e);
          if(u && w <= d)
          {
            memset(slide + w, 0, e);
            w += e;
            d += e;
          }
          else /* or use xadCopyMem */
          {
            do
            {
              slide[w++] = slide[d++];
            } while(--e);
          }
          if(w == 0x4000)
          {
            Zipflush(zd, w);
            w = u = 0;
          }
        } while(n);

        ExState = 0;
      }
      break;
    }

    /* store character for next iteration */
    lchar = nchar;
  }

  /* flush out slide */
  Zipflush(zd, w);
}

/**************************************************************************************************/

static xadINT32 CheckZipPWD(struct ZipData *zd, struct xadMasterBase *xadMasterBase, xadUINT32 val)
{
  xadUINT32 k[3], i;
  xadSTRPTR pwd;
  xadUINT8 a, b = 0;
  xadUINT16 tmp;

  if(!(pwd = zd->Password) || !*pwd)
    return XADERR_PASSWORD;

  k[0] = 305419896;
  k[1] = 591751049;
  k[2] = 878082192;

  while(*pwd)
  {
    k[0] = xadCalcCRC32(XADM XADCRC32_ID1, k[0], 1, (xadUINT8 *) pwd++);
    k[1] += (k[0] & 0xFF);
    k[1] = k[1] * 134775813 + 1;
    a = k[1] >> 24;
    k[2] = xadCalcCRC32(XADM XADCRC32_ID1, k[2], 1, &a);
  }

  zd->Flags ^= (1<<0); /* temporary remove cryption flag ! */
  for(i = 0; i < 12; ++i)
  {
    tmp = k[2] | 2;
    b = Zipgetbyte(zd) ^ ((tmp * (tmp ^ 1)) >> 8);
    k[0] = xadCalcCRC32(XADM XADCRC32_ID1, k[0], 1, &b);
    k[1] += (k[0] & 0xFF);
    k[1] = k[1] * 134775813 + 1;
    a = k[1] >> 24;
    k[2] = xadCalcCRC32(XADM XADCRC32_ID1, k[2], 1, &a);
  }
  zd->Flags ^= (1<<0); /* reset cryption flag ! */

  zd->Keys[0] = k[0];
  zd->Keys[1] = k[1];
  zd->Keys[2] = k[2];

  return (val == b) ? XADERR_OK : XADERR_PASSWORD;
}

/**************************************************************************************************/

XADUNARCHIVE(Zip)
{
  xadINT32 err = 0;
  xadUINT32 crc = (xadUINT32) ~0;
  struct xadFileInfo *fi;

  fi = ai->xai_CurFile;

  if(ZIPPI(fi)->CompressionMethod == ZIPM_STORED && !(fi->xfi_Flags & XADFIF_CRYPTED))
    err = xadHookTagAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai, XAD_GETCRC32, &crc, TAG_DONE);
  else if(ZIPPI(fi)->CompressionMethod == ZIPM_COPY) /* crc is automatically 0 */
    err = xadHookAccess(XADM XADAC_COPY, fi->xfi_Size, 0, ai);
  else
  {
    struct ZipData *zd;

    if((zd = (struct ZipData *) xadAllocVec(XADM
    sizeof(struct ZipData), XADMEMF_PUBLIC|XADMEMF_CLEAR)))
    {
      zd->CRC = crc;
      zd->Password = ai->xai_Password;
      zd->insize = zd->csize = fi->xfi_CrunchSize;
      zd->ucsize = fi->xfi_Size;
      zd->Flags = ZIPPI(fi)->Flags;
      zd->xadMasterBase = xadMasterBase;
      zd->ai = ai;
      zd->inpos = zd->inend = zd->inbuf+ZIPWSIZE;

      if(zd->Flags & (1<<0))
        err = CheckZipPWD(zd, xadMasterBase, (zd->Flags & (1<<3) ?
        ZIPPI(fi)->Date>>8 : ZIPPI(fi)->CRC32>>24) & 0xFF);

      if(!err)
      {
        switch(ZIPPI(fi)->CompressionMethod)
        {
        case ZIPM_DEFLATED:
          if(Zipinflate(zd) && !zd->errcode)
            err = XADERR_ILLEGALDATA;
          break;
        case ZIPM_SHRUNK:
          Zipunshrink(zd); break;
        case ZIPM_IMPLODED:
          Zipexplode(zd); break;
        case ZIPM_REDUCED1: case ZIPM_REDUCED2: case ZIPM_REDUCED3: case ZIPM_REDUCED4:
          Zipunreduce(zd, ZIPPI(fi)->CompressionMethod); break;
        case ZIPM_STORED: /* for crypted files! */
          {
            xadUINT32 i, w = 0;
            for(i = zd->ucsize; i && !zd->errcode; --i)
            {
              zd->Slide[w++] = Zipgetbyte(zd);
              if(w >= ZIPWSIZE)
              {
                Zipflush(zd, w);
                w = 0;
              }
            }
            if(w && !zd->errcode)
              Zipflush(zd, w);
          }
          break;
        default:
          err = XADERR_DATAFORMAT;
          break;
        }
      }
      if(!err)
        err = zd->errcode;
      crc = zd->CRC;

      xadFreeObjectA(XADM zd,0);
    }
    else
      err = XADERR_NOMEMORY;
  }

  if(!err && ~crc != ZIPPI(fi)->CRC32)
    err = XADERR_CHECKSUM;
  return err;
}
#endif
