#define STB_TRUETYPE_IMPLEMENTATION

#define NULL ((void *)0)
typedef int size_t;

extern double zfloor(double x);
extern double zceil(double x);
extern double zsqrt(double x);
extern double zpow(double x, double y);
extern double zfmod(double x, double y);
extern double zcos(double x);
extern double zacos(double x);
extern double zfabs(double x);
extern void *zmalloc(int len);
extern void zfree(void *p);
extern int zstrlen(const char *s);
extern void *zmemcpy(void *dst, const void *src, int len);
extern void *zmemset(void *dst, int val, int len);

#define STBTT_ifloor(x)   ((int) zfloor(x))
#define STBTT_iceil(x)    ((int) zceil(x))
#define STBTT_sqrt(x)      zsqrt(x)
#define STBTT_pow(x,y)     zpow(x,y)
#define STBTT_fmod(x,y)    zfmod(x,y)
#define STBTT_cos(x)       zcos(x)
#define STBTT_acos(x)      zacos(x)
#define STBTT_fabs(x)   zfabs(x)
#define STBTT_malloc(x,u)  ((void)(u),zmalloc(x))
#define STBTT_free(x,u) ((void)(u),zfree(x))
#define STBTT_assert(x)    
#define STBTT_strlen(x)    zstrlen(x)
#define STBTT_memcpy       zmemcpy
#define STBTT_memset    zmemset

#include "stb_truetype.h"

