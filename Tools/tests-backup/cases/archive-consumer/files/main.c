#include <stdio.h>
#ifdef HAVE_ANSWER
#include <answer.h>
#endif
int main(void) {
#ifdef HAVE_ANSWER
    printf("%d\n", answer());
#else
    puts("without-library");
#endif
    return 0;
}
