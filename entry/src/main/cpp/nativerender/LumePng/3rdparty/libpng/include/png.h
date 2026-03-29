/*
 * Minimal stub header for libpng
 * This provides just enough definitions for compilation without the actual library
 */

#ifndef PNG_H
#define PNG_H

#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Basic types */
typedef unsigned char png_byte;
typedef png_byte *png_bytep;
typedef const png_byte *png_const_bytep;
typedef png_byte **png_bytepp;
typedef png_byte ***png_byteppp;

typedef unsigned int png_uint_32;
typedef int png_int_32;
typedef unsigned short png_uint_16;
typedef short png_int_16;

typedef size_t png_size_t;
typedef ptrdiff_t png_ptrdiff_t;

typedef void *png_voidp;
typedef const void *png_const_voidp;
typedef png_voidp *png_voidpp;

typedef double png_doublep;
typedef const char *png_const_charp;
typedef png_int_32 png_fixed_point;

/* Pointers to structures */
typedef struct png_struct_def png_struct;
typedef struct png_info_def png_info;
typedef struct png_unknown_chunk_def png_unknown_chunk;

typedef png_struct *png_structp;
typedef png_struct **png_structpp;
typedef const png_struct *png_const_structp;
typedef png_info *png_infop;
typedef png_info **png_infopp;
typedef const png_info *png_const_infop;
typedef png_unknown_chunk *png_unknown_chunkp;

/* Function pointer types */
typedef void (*png_error_ptr) (png_structp, png_const_charp);
typedef void (*png_rw_ptr) (png_structp, png_bytep, png_size_t);
typedef void (*png_flush_ptr) (png_structp);
typedef void (*png_read_status_ptr) (png_structp, png_uint_32, int);
typedef void (*png_write_status_ptr) (png_structp, png_uint_32, int);
typedef void (*png_progressive_info_ptr) (png_structp, png_infop);
typedef void (*png_progressive_end_ptr) (png_structp, png_infop);
typedef void (*png_progressive_row_ptr) (png_structp, png_bytep, png_uint_32, int);
typedef void (*png_user_transform_ptr) (png_structp, png_bytep, png_uint_32, int);
typedef int (*png_user_chunk_ptr) (png_structp, png_unknown_chunkp);
typedef void (*png_longjmp_ptr) (jmp_buf, int);

/* Color type flags */
#define PNG_COLOR_MASK_PALETTE    1
#define PNG_COLOR_MASK_COLOR      2
#define PNG_COLOR_MASK_ALPHA      4

#define PNG_COLOR_TYPE_GRAY 0
#define PNG_COLOR_TYPE_PALETTE  (PNG_COLOR_MASK_COLOR | PNG_COLOR_MASK_PALETTE)
#define PNG_COLOR_TYPE_RGB        (PNG_COLOR_MASK_COLOR)
#define PNG_COLOR_TYPE_RGB_ALPHA  (PNG_COLOR_MASK_COLOR | PNG_COLOR_MASK_ALPHA)
#define PNG_COLOR_TYPE_GRAY_ALPHA (PNG_COLOR_MASK_ALPHA)

#define PNG_COLOR_TYPE_RGBA  PNG_COLOR_TYPE_RGB_ALPHA
#define PNG_COLOR_TYPE_GA    PNG_COLOR_TYPE_GRAY_ALPHA

/* Interlace types */
#define PNG_INTERLACE_NONE        0
#define PNG_INTERLACE_ADAM7       1

/* Compression types */
#define PNG_COMPRESSION_TYPE_BASE 0
#define PNG_COMPRESSION_TYPE_DEFAULT PNG_COMPRESSION_TYPE_BASE

/* Filter types */
#define PNG_FILTER_TYPE_BASE      0
#define PNG_FILTER_TYPE_DEFAULT   PNG_FILTER_TYPE_BASE

/* Filler positions */
#define PNG_FILLER_BEFORE 0
#define PNG_FILLER_AFTER 1

/* Scale/strip flags */
#define PNG_SCALE_16_TO_8 1

/* Version info */
#define PNG_LIBPNG_VER_STRING "1.6.40"
#define PNG_LIBPNG_VER_SONUM   16
#define PNG_LIBPNG_VER_DLLNUM  16
#define PNG_LIBPNG_VER_MAJOR   1
#define PNG_LIBPNG_VER_MINOR   6
#define PNG_LIBPNG_VER_RELEASE 40
#define PNG_LIBPNG_VER_BUILD   0
#define PNG_LIBPNG_VER 10640

/* Limits */
#define PNG_UINT_32_MAX 0x7fffffffU
#define PNG_SIZE_MAX ((png_size_t)(-1))

/* jmp_buf related */
#define png_jmpbuf(png_ptr) (*((jmp_buf*) (png_ptr)->jmp_buf_ptr))

/* Struct definitions */
struct png_struct_def {
    jmp_buf jmp_buf_local;
    jmp_buf *jmp_buf_ptr;
    jmp_buf *jmp_buf_for_read;
    jmp_buf *jmp_buf_for_write;

    png_error_ptr error_fn;
    png_error_ptr warning_fn;
    png_voidp error_ptr;

    png_rw_ptr write_data_fn;
    png_rw_ptr read_data_fn;
    png_flush_ptr output_flush_fn;

    png_voidp io_ptr;

    png_uint_32 mode;
    png_uint_32 flags;
    png_uint_32 transformations;

    void *zstream;
    png_bytep zbuf;
    png_size_t zbuf_size;

    int zlib_level;
    int zlib_method;
    int zlib_window_bits;
    int zlib_mem_level;
    int zlib_strategy;

    png_uint_32 width;
    png_uint_32 height;

    png_uint_32 valid;
    png_uint_32 rowbytes;

    int bit_depth;
    int color_type;
    int compression_type;
    int filter_type;
    int interlace_type;
    int channels;
    int pixel_depth;

    void *user_transform_ptr;
    png_user_transform_ptr user_transform_fn;

    png_bytep big_row_buf;
    png_bytep row_buf;
    png_bytep prev_row;

    png_uint_32 row_number;
    png_uint_32 chunk_name;

    png_bytep chunkdata;
    png_size_t chunkdata_max;
    png_size_t chunkdata_len;

    void *palette_lookup;
    void *dither_index;
    void *gamma_shift;
    void *gamma_16_table;
    void *gamma_16_from_1;
    void *gamma_16_to_1;
    void *gamma_from_1;
    void *gamma_to_1;
    png_bytep gamma_table;

    int free_me;
    int idat_size;
    int process_mode;
    int state;

    png_uint_32 crc;

    png_voidp mem_ptr;
    png_voidp (*malloc_fn) (png_voidp, png_size_t);
    void (*free_fn) (png_voidp, png_voidp);
};

struct png_info_def {
    png_uint_32 width;
    png_uint_32 height;
    unsigned int bit_depth;
    unsigned int color_type;
    unsigned int compression_type;
    unsigned int filter_type;
    unsigned int interlace_type;

    png_uint_32 valid;
    png_uint_32 rowbytes;

    int channels;
    int pixel_depth;

    png_bytepp row_pointers;

    png_uint_32 num_palette;
    void *palette;

    int num_trans;
    png_bytep trans_alpha;
    void *trans_color;

    int num_text;
    int max_text;
    void *text;

    int num_splt;
    int max_splt;
    void *splt_palettes;

    int num_unknown_chunks;
    int max_unknown_chunks;
    void *unknown_chunks;

    void *hist;

    png_uint_32 x_pixels_per_unit;
    png_uint_32 y_pixels_per_unit;
    unsigned int phys_unit_type;

    double gamma;

    png_bytep iccp_name;
    png_bytep iccp_profile;
    png_uint_32 iccp_proflen;
    int iccp_compression;

    void *sbit_sig;
    void *sbit_g;
    void *sbit_b;
    void *sbit_a;

    void *unknown_1;
    void *unknown_2;
    void *unknown_3;
    void *unknown_4;
};

/* Function declarations */
png_structp png_create_read_struct(png_const_charp user_png_ver, png_voidp error_ptr, png_error_ptr error_fn, png_error_ptr warn_fn);
png_structp png_create_write_struct(png_const_charp user_png_ver, png_voidp error_ptr, png_error_ptr error_fn, png_error_ptr warn_fn);

void png_destroy_read_struct(png_structpp png_ptr_ptr, png_infopp info_ptr_ptr, png_infopp end_info_ptr_ptr);
void png_destroy_write_struct(png_structpp png_ptr_ptr, png_infopp info_ptr_ptr);

png_infop png_create_info_struct(png_structp png_ptr);
void png_destroy_info_struct(png_structp png_ptr, png_infopp info_ptr_ptr);

void png_init_io(png_structp png_ptr, FILE *fp);

void png_set_read_fn(png_structp png_ptr, png_voidp io_ptr, png_rw_ptr read_data_fn);
void png_set_write_fn(png_structp png_ptr, png_voidp io_ptr, png_rw_ptr write_data_fn, png_flush_ptr output_flush_fn);

png_voidp png_get_io_ptr(png_structp png_ptr);

void png_read_png(png_structp png_ptr, png_infop info_ptr, int transforms, png_voidp params);
void png_write_png(png_structp png_ptr, png_infop info_ptr, int transforms, png_voidp params);

void png_read_info(png_structp png_ptr, png_infop info_ptr);
void png_read_update_info(png_structp png_ptr, png_infop info_ptr);

void png_read_image(png_structp png_ptr, png_bytepp image);
void png_read_row(png_structp png_ptr, png_bytep row, png_bytep display_row);
void png_read_end(png_structp png_ptr, png_infop info_ptr);

int png_sig_cmp(png_const_bytep sig, png_size_t start, png_size_t num_to_check);
void png_set_sig_bytes(png_structp png_ptr, int num_bytes);

/* Get functions */
png_uint_32 png_get_image_width(png_const_structp png_ptr, png_const_infop info_ptr);
png_uint_32 png_get_image_height(png_const_structp png_ptr, png_const_infop info_ptr);
png_byte png_get_bit_depth(png_const_structp png_ptr, png_const_infop info_ptr);
png_byte png_get_color_type(png_const_structp png_ptr, png_const_infop info_ptr);
png_byte png_get_filter_type(png_const_structp png_ptr, png_const_infop info_ptr);
png_byte png_get_interlace_type(png_const_structp png_ptr, png_const_infop info_ptr);
png_byte png_get_compression_type(png_const_structp png_ptr, png_const_infop info_ptr);
png_byte png_get_channels(png_const_structp png_ptr, png_const_infop info_ptr);
png_uint_32 png_get_rowbytes(png_const_structp png_ptr, png_const_infop info_ptr);
png_uint_32 png_get_valid(png_const_structp png_ptr, png_const_infop info_ptr, png_uint_32 flag);
png_bytepp png_get_rows(png_const_structp png_ptr, png_const_infop info_ptr);

/* Set functions */
void png_set_IHDR(png_structp png_ptr, png_infop info_ptr, png_uint_32 width, png_uint_32 height, int bit_depth, int color_type, int interlace_method, int compression_method, int filter_method);
void png_set_rows(png_structp png_ptr, png_infop info_ptr, png_bytepp row_pointers);

/* Transform functions */
void png_set_expand(png_structp png_ptr);
void png_set_expand_gray_1_2_4_to_8(png_structp png_ptr);
void png_set_palette_to_rgb(png_structp png_ptr);
void png_set_tRNS_to_alpha(png_structp png_ptr);
void png_set_gray_to_rgb(png_structp png_ptr);
void png_set_rgb_to_gray(png_structp png_ptr, int error_action, double red, double green);
void png_set_rgb_to_gray_fixed(png_structp png_ptr, int error_action, png_fixed_point red, png_fixed_point green);
void png_set_scale_16(png_structp png_ptr);
void png_set_strip_16(png_structp png_ptr);
void png_set_strip_alpha(png_structp png_ptr);
void png_set_swap_alpha(png_structp png_ptr);
void png_set_swap(png_structp png_ptr);
void png_set_packing(png_structp png_ptr);
void png_set_packswap(png_structp png_ptr);
void png_set_shift(png_structp png_ptr, const void *true_bits);
void png_set_bgr(png_structp png_ptr);
void png_set_invert_mono(png_structp png_ptr);
void png_set_filler(png_structp png_ptr, png_uint_32 filler, int flags);
void png_set_add_alpha(png_structp png_ptr, png_uint_32 filler, int flags);
void png_set_interlace_handling(png_structp png_ptr);

/* Error functions */
void png_error(png_structp png_ptr, png_const_charp error_message);
void png_warning(png_structp png_ptr, png_const_charp warning_message);
void png_chunk_error(png_structp png_ptr, png_const_charp error_message);
void png_chunk_warning(png_structp png_ptr, png_const_charp warning_message);

/* jmp_buf functions */
jmp_buf* png_set_longjmp_fn(png_structp png_ptr, png_longjmp_ptr longjmp_fn, size_t jmp_buf_size);

#ifdef __cplusplus
}
#endif

#endif /* PNG_H */