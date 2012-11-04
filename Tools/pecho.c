#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[])
{
        int opt, len, i, si, di;
        int newline, left, right, occupy;
        char buf[128], *str;

        newline = 1;
        left = right = occupy = 0;
        while ((opt = getopt(argc, argv, "nlro:")) != -1) {
                switch (opt) {
                case 'n':
                        newline = 0;
                        break;
                case 'l':
                        left = 1;
                        break;
                case 'r':
                        right = 1;
                        break;
                case 'o':
                        occupy = atoi(optarg);
                        break;
                default: /* '?' */
                        fprintf(stderr, "Usage: %s [-o size] [-n] [-l] [r] string\n", argv[0]);
                        exit(EXIT_FAILURE);
                }
        }

/*
        printf("newline=%d; left=%d; right=%d; occupy=%d\n", newline, left, right, occupy);
*/

        if (optind >= argc) {
/*
                fprintf(stderr, "Expected argument after options\n");
*/
                exit(EXIT_FAILURE);
        }

/*
        printf("name argument = %s\n", argv[optind]);
*/

        memset(buf, '\0', 128);
        str = argv[optind++];
        len = strlen(str);
        si = di = 0;
        if (right && occupy) {
                di = occupy - len;
                if (di < 0) {
                        di = 0;
                        si = len - occupy;
                        len = occupy;
                }
        }
        for (i=0; i<di; i++)
                buf[i] = ' ';
        for (i=len; i>0; i--)
                buf[di++] = str[si++];
        for (;di<occupy; di++)
                buf[di] = ' ';
        fprintf( stdout, "%s", buf);

	for (i=optind; i<argc; i++)
		fprintf(stdout, " %s", argv[i]);

        if (newline)
		fprintf(stdout, "\n");

        exit(EXIT_SUCCESS);
}
