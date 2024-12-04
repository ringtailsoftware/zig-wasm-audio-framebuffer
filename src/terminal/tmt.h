#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

#define ssize_t int

typedef struct {
    int fixme;
} mbstate_t;

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




/* Copyright (c) 2017 Rob King
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *   * Neither the name of the copyright holder nor the
 *     names of contributors may be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHORS,
 * COPYRIGHT HOLDERS, OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
 * USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef TMT_H
#define TMT_H

/**** INVALID WIDE CHARACTER */
#ifndef TMT_INVALID_CHAR
#define TMT_INVALID_CHAR ((wchar_t)0xfffd)
#endif

/**** INPUT SEQUENCES */
#define TMT_KEY_UP             "\033[A"
#define TMT_KEY_DOWN           "\033[B"
#define TMT_KEY_RIGHT          "\033[C"
#define TMT_KEY_LEFT           "\033[D"
#define TMT_KEY_HOME           "\033[1~"
#define TMT_KEY_END            "\033[4~"
#define TMT_KEY_INSERT         "\033[L"
#define TMT_KEY_BACKSPACE      "\x7f"
#define TMT_KEY_DELETE         "\033[3~"
#define TMT_KEY_ESCAPE         "\x1b"
#define TMT_KEY_BACK_TAB       "\033\x09"
#define TMT_KEY_PAGE_UP        "\033[5~"
#define TMT_KEY_PAGE_DOWN      "\033[6~"
#define TMT_KEY_F1             "\033[[A"
#define TMT_KEY_F2             "\033[[B"
#define TMT_KEY_F3             "\033[[C"
#define TMT_KEY_F4             "\033[[D"
#define TMT_KEY_F5             "\033[[E"
#define TMT_KEY_F6             "\033[17~"
#define TMT_KEY_F7             "\033[18~"
#define TMT_KEY_F8             "\033[19~"
#define TMT_KEY_F9             "\033[20~"
#define TMT_KEY_F10            "\033[21~"
#define TMT_KEY_F11            "\033[23~"
#define TMT_KEY_F12            "\033[24~"

/**** BASIC DATA STRUCTURES */
//typedef struct TMT TMT;

#define BUF_MAX 100
#define PAR_MAX 8
#define TITLE_MAX 128
#define TAB 8
#define MAX(x, y) (((size_t)(x) > (size_t)(y)) ? (size_t)(x) : (size_t)(y))
#define MIN(x, y) (((size_t)(x) < (size_t)(y)) ? (size_t)(x) : (size_t)(y))
#define CLINE(vt) (vt)->screen.lines[MIN((vt)->curs.r, (vt)->screen.nline - 1)]

#define SCR_DEF ((size_t)-1)

#define P0(x) (vt->pars[x])
#define P1(x) (vt->pars[x]? vt->pars[x] : 1)
#define CB(vt, m, a) ((vt)->cb? (vt)->cb(m, vt, a, (vt)->p) : (void)0)
#define INESC ((vt)->state)

#define COMMON_VARS             \
    TMTSCREEN *s = &vt->screen; \
    TMTPOINT *c = &vt->curs;    \
    TMTLINE *l = CLINE(vt);     \
    TMTCHAR *t = vt->tabs->chars

#define HANDLER(name) static void name (TMT *vt) { COMMON_VARS;



typedef enum{
    TMT_COLOR_DEFAULT = -1,
    TMT_COLOR_BLACK = 1,
    TMT_COLOR_RED,
    TMT_COLOR_GREEN,
    TMT_COLOR_YELLOW,
    TMT_COLOR_BLUE,
    TMT_COLOR_MAGENTA,
    TMT_COLOR_CYAN,
    TMT_COLOR_WHITE,
    TMT_COLOR_MAX
} tmt_color_t;

typedef struct TMTATTRS TMTATTRS;
struct TMTATTRS{
    bool bold;
    bool dim;
    bool underline;
    bool blink;
    bool reverse;
    bool invisible;
    tmt_color_t fg;
    tmt_color_t bg;
};

typedef struct TMTCHAR TMTCHAR;
struct TMTCHAR{
    wchar_t c;
    TMTATTRS a;
};

typedef struct TMTPOINT TMTPOINT;
struct TMTPOINT{
    size_t r;
    size_t c;
};

typedef struct TMTLINE TMTLINE;
struct TMTLINE{
    bool dirty;
    TMTCHAR chars[];
};

typedef struct TMTSCREEN TMTSCREEN;
struct TMTSCREEN{
    size_t nline;
    size_t ncol;

    TMTLINE **lines;
};

/**** CALLBACK SUPPORT */
typedef enum{
    TMT_MSG_MOVED,
    TMT_MSG_UPDATE,
    TMT_MSG_ANSWER,
    TMT_MSG_TITLE,
    TMT_MSG_BELL,
    TMT_MSG_CURSOR,
    TMT_MSG_SETMODE,
    TMT_MSG_UNSETMODE,
} tmt_msg_t;

typedef void (*TMTCALLBACK)(tmt_msg_t m, struct TMT *v, const void *r, void *p);

struct TMT{
    TMTPOINT curs, oldcurs;
    TMTATTRS attrs, oldattrs;

    // VT100-derived terminals have a wrap behavior where the cursor "sticks"
    // at the end of a line instead of immediately wrapping.  This allows you
    // to use the last column without getting extra blank lines or
    // unintentionally scrolling the screen.  The logic we implement for it
    // is not exactly like that of a real VT100, but it seems to be
    // sufficient for things to work as expected in the use cases and with
    // the terminfo files I've tested with.  Specifically, I call the case
    // where the cursor has advanced exactly one position past the rightmost
    // column "hanging".  A rough description of the current algorithm is
    // that there are two cases which each have two sub-cases:
    // 1. You're hanging onto the next line below.  That is, you're not at
    //    the bottom of the screen/scrolling region.
    //    1a. If you receive a newline, hanging mode is canceled and nothing
    //        else happens.  In particular, you do *not* advanced to the next
    //        line.  You're already *at* the start of the "next" line.
    //    2b. If you receive a printable character, just cancel hanging mode.
    // 2. You're hanging past the bottom of the screen/scrolling region.
    //    2a. If you receive a newline or printable character, scroll the
    //        screen up one line and cancel hanging.
    //    2b. If you receive a cursor reposition or whatever, cancel hanging.
    // Below, hang is 0 if not hanging, or 1 or 2 as described above.
    int hang;

    // Name of the terminal for XTVERSION (if null, use default).
    char * terminal_name;

    size_t minline;
    size_t maxline;

    bool dirty, acs, ignored;
    TMTSCREEN screen;
    TMTLINE *tabs;

    TMTCALLBACK cb;
    void *p;
    const wchar_t *acschars;

    int charset;  // Are we in G0 or G1?
    int xlate[2]; // What's in the charset?  0=ASCII, 1=DEC Special Graphics

    bool decode_unicode; // Try to decode characters to ACS equivalents?

    mbstate_t ms;
    size_t nmb;
    char mb[BUF_MAX + 1];

    char title[TITLE_MAX + 1];
    size_t ntitle;

    size_t pars[PAR_MAX];
    size_t npar;
    size_t arg;
    bool q;
    enum {S_NUL, S_ESC, S_ARG, S_TITLE, S_TITLE_ARG, S_GT_ARG, S_LPAREN, S_RPAREN} state;
};


typedef struct TMT TMT;


/**** PUBLIC FUNCTIONS */
TMT *tmt_open(size_t nline, size_t ncol, TMTCALLBACK cb, void *p,
              const wchar_t *acs);
bool tmt_set_unicode_decode(TMT *vt, bool v);
void tmt_close(TMT *vt);
bool tmt_resize(TMT *vt, size_t nline, size_t ncol);
void tmt_write(TMT *vt, const char *s, size_t n);
const TMTSCREEN *tmt_screen(const TMT *vt);
const TMTPOINT *tmt_cursor(const TMT *vt);
void tmt_clean(TMT *vt);
void tmt_reset(TMT *vt);

#endif
