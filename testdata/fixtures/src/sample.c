/**
 * sample.c — comprehensive C syntax fixture for parser testing.
 * Covers: preprocessor directives, macros, typedef, structs, unions, enums,
 * function pointers, variadic functions, bitfields, pointer arithmetic,
 * dynamic memory, file I/O, signal handling, setjmp/longjmp, inline asm.
 */

#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <setjmp.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* -------------------------------------------------------------------------- */
/* Preprocessor & macros                                                      */
/* -------------------------------------------------------------------------- */

#define MAX_RETRIES   3
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define MIN(a, b)     ((a) < (b) ? (a) : (b))
#define MAX(a, b)     ((a) > (b) ? (a) : (b))
#define CLAMP(v, lo, hi) (MIN(MAX((v), (lo)), (hi)))

#define STRINGIFY(x)  #x
#define CONCAT(a, b)  a##b

#ifdef NDEBUG
#  define DLOG(fmt, ...) ((void)0)
#else
#  define DLOG(fmt, ...) fprintf(stderr, "[DEBUG] " fmt "\n", ##__VA_ARGS__)
#endif

/* -------------------------------------------------------------------------- */
/* Typedefs & primitive aliases                                                */
/* -------------------------------------------------------------------------- */

typedef uint8_t  u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t   i8;
typedef int32_t  i32;
typedef int64_t  i64;
typedef size_t   usize;

/* -------------------------------------------------------------------------- */
/* Enums                                                                       */
/* -------------------------------------------------------------------------- */

typedef enum {
    STATUS_PENDING = 0,
    STATUS_RUNNING,
    STATUS_DONE,
    STATUS_FAILED
} Status;

static const char *status_to_str(Status s) {
    switch (s) {
    case STATUS_PENDING: return "pending";
    case STATUS_RUNNING: return "running";
    case STATUS_DONE:    return "done";
    case STATUS_FAILED:  return "failed";
    default:             return "unknown";
    }
}

/* -------------------------------------------------------------------------- */
/* Structs & unions                                                            */
/* -------------------------------------------------------------------------- */

typedef struct {
    char   id[37];   /* UUID string including null terminator */
    char   name[64];
    char   email[128];
    Status status;
    u64    created_at;
} User;

typedef struct Node {
    void          *data;
    struct Node   *next;
    struct Node   *prev;
} Node;

typedef struct {
    Node  *head;
    Node  *tail;
    usize  length;
} LinkedList;

/* Bitfield struct */
typedef struct {
    unsigned int is_admin   : 1;
    unsigned int is_active  : 1;
    unsigned int is_premium : 1;
    unsigned int reserved   : 29;
} UserFlags;

/* Tagged union */
typedef enum { VAL_INT, VAL_FLOAT, VAL_STR } ValTag;

typedef struct {
    ValTag tag;
    union {
        i64   as_int;
        double as_float;
        char  *as_str;
    };
} Value;

/* -------------------------------------------------------------------------- */
/* Function pointers & callbacks                                               */
/* -------------------------------------------------------------------------- */

typedef int (*CompareFn)(const void *a, const void *b);
typedef void (*FreeFn)(void *ptr);

static int compare_int(const void *a, const void *b) {
    int x = *(const int *)a;
    int y = *(const int *)b;
    return (x > y) - (x < y);
}

typedef struct {
    void     *data;
    usize     len;
    usize     cap;
    FreeFn    free_item;
} Vec;

static Vec *vec_new(usize initial_cap, FreeFn free_item) {
    Vec *v = malloc(sizeof(*v));
    if (!v) return NULL;
    v->data = malloc(initial_cap * sizeof(void *));
    if (!v->data) { free(v); return NULL; }
    v->len = 0;
    v->cap = initial_cap;
    v->free_item = free_item;
    return v;
}

static bool vec_push(Vec *v, void *item) {
    if (v->len == v->cap) {
        usize new_cap = v->cap * 2;
        void *new_data = realloc(v->data, new_cap * sizeof(void *));
        if (!new_data) return false;
        v->data = new_data;
        v->cap  = new_cap;
    }
    ((void **)v->data)[v->len++] = item;
    return true;
}

static void vec_free(Vec *v) {
    if (!v) return;
    if (v->free_item) {
        for (usize i = 0; i < v->len; i++) {
            v->free_item(((void **)v->data)[i]);
        }
    }
    free(v->data);
    free(v);
}

/* -------------------------------------------------------------------------- */
/* Variadic functions                                                          */
/* -------------------------------------------------------------------------- */

static int sum_ints(int count, ...) {
    va_list args;
    va_start(args, count);
    int total = 0;
    for (int i = 0; i < count; i++) {
        total += va_arg(args, int);
    }
    va_end(args);
    return total;
}

static int safe_snprintf(char *buf, usize size, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(buf, size, fmt, ap);
    va_end(ap);
    return n;
}

/* -------------------------------------------------------------------------- */
/* Pointer arithmetic & string manipulation                                    */
/* -------------------------------------------------------------------------- */

static char *str_dup(const char *src) {
    if (!src) return NULL;
    usize len = strlen(src);
    char *dst = malloc(len + 1);
    if (!dst) return NULL;
    memcpy(dst, src, len + 1);
    return dst;
}

static char *str_trim(const char *s) {
    while (*s == ' ' || *s == '\t' || *s == '\n') s++;
    if (*s == '\0') return str_dup("");
    const char *end = s + strlen(s) - 1;
    while (end > s && (*end == ' ' || *end == '\t' || *end == '\n')) end--;
    usize len = (usize)(end - s) + 1;
    char *out = malloc(len + 1);
    if (!out) return NULL;
    memcpy(out, s, len);
    out[len] = '\0';
    return out;
}

/* -------------------------------------------------------------------------- */
/* Error handling via errno                                                    */
/* -------------------------------------------------------------------------- */

static char *read_file(const char *path) {
    FILE *fp = fopen(path, "rb");
    if (!fp) {
        DLOG("fopen(%s): %s", path, strerror(errno));
        return NULL;
    }
    if (fseek(fp, 0, SEEK_END) != 0) { fclose(fp); return NULL; }
    long size = ftell(fp);
    if (size < 0) { fclose(fp); return NULL; }
    rewind(fp);

    char *buf = malloc((usize)size + 1);
    if (!buf) { fclose(fp); return NULL; }
    if (fread(buf, 1, (usize)size, fp) != (usize)size) {
        free(buf);
        fclose(fp);
        return NULL;
    }
    buf[size] = '\0';
    fclose(fp);
    return buf;
}

/* -------------------------------------------------------------------------- */
/* setjmp / longjmp                                                            */
/* -------------------------------------------------------------------------- */

static jmp_buf g_jmp_buf;

static void might_fail(int x) {
    if (x < 0) longjmp(g_jmp_buf, 1);
}

static void jmp_example(void) {
    if (setjmp(g_jmp_buf) != 0) {
        fprintf(stderr, "recovered from longjmp\n");
        return;
    }
    might_fail(-1);
}

/* -------------------------------------------------------------------------- */
/* Signal handling                                                             */
/* -------------------------------------------------------------------------- */

static volatile sig_atomic_t g_interrupted = 0;

static void sigint_handler(int sig) {
    (void)sig;
    g_interrupted = 1;
}

/* -------------------------------------------------------------------------- */
/* Linked list operations                                                      */
/* -------------------------------------------------------------------------- */

static Node *list_push_front(LinkedList *list, void *data) {
    Node *node = malloc(sizeof(*node));
    if (!node) return NULL;
    node->data = data;
    node->prev = NULL;
    node->next = list->head;
    if (list->head) list->head->prev = node;
    else            list->tail = node;
    list->head = node;
    list->length++;
    return node;
}

static void list_free(LinkedList *list, FreeFn free_item) {
    Node *cur = list->head;
    while (cur) {
        Node *nxt = cur->next;
        if (free_item) free_item(cur->data);
        free(cur);
        cur = nxt;
    }
    list->head = list->tail = NULL;
    list->length = 0;
}

/* -------------------------------------------------------------------------- */
/* Static assertions                                                           */
/* -------------------------------------------------------------------------- */

_Static_assert(sizeof(u64) == 8, "u64 must be 8 bytes");
_Static_assert(sizeof(UserFlags) == sizeof(u32), "UserFlags must fit in u32");

/* -------------------------------------------------------------------------- */
/* Entry point                                                                 */
/* -------------------------------------------------------------------------- */

int main(void) {
    signal(SIGINT, sigint_handler);

    int nums[] = {5, 3, 8, 1, 9, 2, 7};
    qsort(nums, ARRAY_SIZE(nums), sizeof(nums[0]), compare_int);
    for (usize i = 0; i < ARRAY_SIZE(nums); i++) {
        printf("%d ", nums[i]);
    }
    printf("\n");

    char *trimmed = str_trim("  hello world  ");
    printf("'%s'\n", trimmed);
    free(trimmed);

    printf("sum = %d\n", sum_ints(4, 10, 20, 30, 40));

    Value v = { .tag = VAL_INT, .as_int = 42 };
    printf("value tag=%d int=%lld\n", v.tag, (long long)v.as_int);

    jmp_example();

    DLOG("done, interrupted=%d", g_interrupted);
    return 0;
}
