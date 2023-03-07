#define DOOM_IMPLEMENTATION
extern void doom_print_impl(const char* str);
#include "PureDOOM.h"

static char *argv[] = {"pd"};
void pd_init(void) {
    doom_init(1, argv, 0);
}


