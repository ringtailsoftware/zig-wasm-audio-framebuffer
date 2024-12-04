#ifndef TERMINAL_H
#define TERMINAL_H 1
#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdarg.h>

#define ssize_t int

typedef struct {
    int fixme;
} mbstate_t;

typedef struct {
    int errno;
} FILE;

static int errno = 0;

static FILE stdin_file;
static FILE stdout_file;
static FILE stderr_file;

#define stdin &stdin_file
#define stdout &stdout_file
#define stderr &stderr_file

extern void *agnes_memcpy(void *dst, const void *src, int n);
extern void agnes_memset(void *dst, uint8_t c, int n);
extern void agnes_print(char *s);
extern void agnes_memmove(void *dst, const void *src, int n);
extern void *agnes_malloc(int n);
extern void agnes_free(void *p);
extern void *agnes_realloc(void *p, int n);
extern int agnes_strlen(const char *s);
extern int agnes_memcmp(void *a, void *b, int n);
size_t agnes_mbrtowc(wchar_t *pwc, const char *s,size_t n, mbstate_t *ps);
extern char *agnes_strchr(const char *s, char c);
extern int agnes_atoi(const char *s);
extern char *agnes_strcat(char *a, const char *b);
extern char *agnes_strcpy(char *a, const char *b);
extern int agnes_snprintf(char * str, size_t size, const char *format,...);
extern int agnes_abs(int a);
extern int agnes_strncmp(const char *s1, const char *s2, size_t n);
extern int agnes_vsnprintf(char * str, size_t size, const char * format, va_list ap);
extern int agnes_fprintf(FILE *, const char * format, ...);
extern void agnes_abort(void);
extern void agnes_exit(int e);
extern char *agnes_strncpy(char * dst, const char * src, size_t len);

static void *agnes_calloc(int n, char c) {
    void *p = agnes_malloc(n);
    if (p != NULL) {
        agnes_memset(p, n, c);
    }
    return p;
}

#define MB_LEN_MAX 16

#define memcpy agnes_memcpy
#define memset agnes_memset
#define memmove agnes_memmove
#define malloc agnes_malloc
#define calloc agnes_calloc
#define free agnes_free
#define realloc agnes_realloc
#define strlen agnes_strlen
#define memcmp agnes_memcmp
#define mbrtowc agnes_mbrtowc
#define strchr agnes_strchr
#define atoi agnes_atoi
#define strcat agnes_strcat
#define strcpy agnes_strcpy
#define snprintf agnes_snprintf
#define abs agnes_abs
#define strncmp agnes_strncmp
#define vsnprintf agnes_vsnprintf
#define fprintf agnes_fprintf
#define abort agnes_abort
#define exit agnes_exit
#define strncpy agnes_strncpy

#include "libvterm/vterm.h"

#endif

