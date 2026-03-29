/*
 * Minimal stub header for libjpeg-turbo
 * This provides just enough definitions for compilation without the actual library
 */

#ifndef JPEGLIB_H
#define JPEGLIB_H

#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Basic types */
typedef unsigned char JSAMPLE;
typedef JSAMPLE *JSAMPROW;
typedef JSAMPROW *JSAMPARRAY;
typedef JSAMPARRAY *JSAMPIMAGE;

typedef unsigned int JDIMENSION;
typedef short JCOEF;
typedef JCOEF *JCOEFPTR;

typedef unsigned char JOCTET;
typedef JOCTET *JOCTET_PTR;

typedef unsigned char UINT8;
typedef unsigned short UINT16;

#define JMSG_STR_PARM_MAX  80
#define JMSG_LENGTH_MAX  200

/* Error codes */
#define JERR_FILE_READ  29
#define JERR_OUT_OF_MEMORY  31

/* Boolean type */
typedef int boolean;
#define FALSE 0
#define TRUE 1

/* Color spaces */
typedef enum {
    JCS_UNKNOWN,
    JCS_GRAYSCALE,
    JCS_RGB,
    JCS_YCbCr,
    JCS_CMYK,
    JCS_YCCK,
    JCS_EXT_RGB,
    JCS_EXT_RGBX,
    JCS_EXT_BGR,
    JCS_EXT_BGRX,
    JCS_EXT_XBGR,
    JCS_EXT_XRGB,
    JCS_EXT_RGBA,
    JCS_EXT_BGRA,
    JCS_EXT_ABGR,
    JCS_EXT_ARGB,
    JCS_RGB565
} J_COLOR_SPACE;

/* DCT methods */
typedef enum {
    JDCT_ISLOW,
    JDCT_IFAST,
    JDCT_FLOAT
} J_DCT_METHOD;

/* Dither modes */
typedef enum {
    JDITHER_NONE,
    JDITHER_ORDERED,
    JDITHER_FS
} J_DITHER_MODE;

/* Buffer modes */
typedef enum {
    JBUF_PASS_THRU,
    JBUF_SAVE_SOURCE,
    JBUF_CRANK_DEST,
    JBUF_SAVE_AND_PASS
} J_BUF_MODE;

/* Constants */
#define DCTSIZE             8
#define DCTSIZE2            64
#define NUM_QUANT_TBLS      4
#define NUM_HUFF_TBLS       4
#define NUM_ARITH_TBLS      16
#define MAX_COMPS_IN_SCAN   4
#define C_MAX_BLOCKS_IN_MCU 10
#define D_MAX_BLOCKS_IN_MCU 10

/* Forward declarations */
struct jpeg_common_struct;
struct jpeg_compress_struct;
struct jpeg_decompress_struct;

typedef struct jpeg_common_struct *j_common_ptr;
typedef struct jpeg_compress_struct *j_compress_ptr;
typedef struct jpeg_decompress_struct *j_decompress_ptr;

/* Error manager */
struct jpeg_error_mgr {
    void (*error_exit) (j_common_ptr cinfo);
    void (*emit_message) (j_common_ptr cinfo, int msg_level);
    void (*output_message) (j_common_ptr cinfo);
    void (*format_message) (j_common_ptr cinfo, char *buffer);
    void (*reset_error_mgr) (j_common_ptr cinfo);
    int msg_code;
    union {
        int i[8];
        char s[JMSG_STR_PARM_MAX];
    } msg_parm;
    int trace_level;
    long num_warnings;
    const char * const * jpeg_message_table;
    int last_jpeg_message;
    const char * const * addon_message_table;
    int first_addon_message;
    int last_addon_message;
};

/* Common structure for both compress and decompress */
struct jpeg_common_struct {
    struct jpeg_error_mgr *err;
    struct jpeg_memory_mgr *mem;
    struct jpeg_progress_mgr *progress;
    void *client_data;
    boolean is_decompressor;
    int global_state;
};

/* Memory manager */
struct jpeg_memory_mgr {
    void * (*alloc_small) (j_common_ptr cinfo, int pool_id, size_t sizeofobject);
    void * (*alloc_large) (j_common_ptr cinfo, int pool_id, size_t sizeofobject);
    JSAMPARRAY (*alloc_sarray) (j_common_ptr cinfo, int pool_id, JDIMENSION samplesperrow, JDIMENSION numrows);
    void (*free_pool) (j_common_ptr cinfo, int pool_id);
    void (*self_destruct) (j_common_ptr cinfo);
    long max_memory_to_use;
    long max_alloc_chunk;
};

/* Source manager */
struct jpeg_source_mgr {
    const JOCTET * next_input_byte;
    size_t bytes_in_buffer;
    void (*init_source) (j_decompress_ptr cinfo);
    boolean (*fill_input_buffer) (j_decompress_ptr cinfo);
    void (*skip_input_data) (j_decompress_ptr cinfo, long num_bytes);
    boolean (*resync_to_restart) (j_decompress_ptr cinfo, int desired);
    void (*term_source) (j_decompress_ptr cinfo);
};

/* Progress monitor */
struct jpeg_progress_mgr {
    void (*progress_monitor) (j_common_ptr cinfo);
    long pass_counter;
    long pass_limit;
    int completed_passes;
    int total_passes;
};

typedef struct jpeg_progress_mgr *jpeg_progress_ptr;

/* Quantization table - must be defined before jpeg_component_info */
typedef struct {
    UINT16 quantval[DCTSIZE2];
    boolean sent_table;
} JQUANT_TBL;

/* Huffman table */
typedef struct {
    UINT8 bits[17];
    UINT8 huffval[256];
    boolean sent_table;
} JHUFF_TBL;

/* Component info */
struct jpeg_component_info {
    int component_id;
    int component_index;
    int h_samp_factor;
    int v_samp_factor;
    int quant_tbl_no;
    int dc_tbl_no;
    int ac_tbl_no;
    JDIMENSION width_in_blocks;
    JDIMENSION height_in_blocks;
    int DCT_h_scaled_size;
    int DCT_v_scaled_size;
    int DCT_scaled_size;
    JDIMENSION downsampled_width;
    JDIMENSION downsampled_height;
    boolean component_needed;
    int MCU_width;
    int MCU_height;
    int MCU_blocks;
    int MCU_sample_width;
    int last_col_width;
    int last_row_height;
    JQUANT_TBL *quant_table;
    void *dct_table;
};

/* Decompression structure */
struct jpeg_decompress_struct {
    struct jpeg_error_mgr *err;
    struct jpeg_memory_mgr *mem;
    struct jpeg_progress_mgr *progress;
    void *client_data;
    boolean is_decompressor;
    int global_state;

    struct jpeg_source_mgr *src;

    JDIMENSION image_width;
    JDIMENSION image_height;
    J_COLOR_SPACE jpeg_color_space;
    J_COLOR_SPACE out_color_space;
    unsigned int scale_num;
    unsigned int scale_denom;
    double output_gamma;
    boolean buffered_image;
    boolean raw_data_out;
    J_DCT_METHOD dct_method;
    boolean do_fancy_upsampling;
    boolean do_block_smoothing;
    boolean quantize_colors;
    J_DITHER_MODE dither_mode;
    boolean two_pass_quantize;
    int desired_number_of_colors;
    boolean enable_1pass_quant;
    boolean enable_external_quant;
    boolean enable_2pass_quant;

    JDIMENSION output_width;
    JDIMENSION output_height;
    int out_color_components;
    int output_components;
    int rec_outbuf_height;
    int actual_number_of_colors;
    JSAMPARRAY colormap;

    JDIMENSION output_scanline;
    int input_scan_number;
    JDIMENSION input_iMCU_row;
    int output_scan_number;
    JDIMENSION output_iMCU_row;
    int (*coef_bits)[DCTSIZE2];

    JQUANT_TBL *quant_tbl_ptrs[NUM_QUANT_TBLS];
    JHUFF_TBL *dc_huff_tbl_ptrs[NUM_HUFF_TBLS];
    JHUFF_TBL *ac_huff_tbl_ptrs[NUM_HUFF_TBLS];

    int data_precision;

    int num_components;
    jpeg_component_info *comp_info;

    boolean progressive_mode;
    boolean arith_code;
    UINT8 arith_dc_L[NUM_ARITH_TBLS];
    UINT8 arith_dc_U[NUM_ARITH_TBLS];
    UINT8 arith_ac_K[NUM_ARITH_TBLS];

    unsigned int restart_interval;
    boolean saw_JFIF_marker;
    UINT8 JFIF_major_version;
    UINT8 JFIF_minor_version;
    UINT8 density_unit;
    UINT16 X_density;
    UINT16 Y_density;
    boolean saw_Adobe_marker;
    UINT8 Adobe_transform;
    boolean CCIR601_sampling;

    struct jpeg_marker_struct *marker_list;

    int max_h_samp_factor;
    int max_v_samp_factor;
    int min_DCT_h_scaled_size;
    int min_DCT_v_scaled_size;

    JDIMENSION total_iMCU_rows;

    JSAMPLE *sample_range_limit;

    int scan_info;
    int max_scan_components;
    int num_scans;

    boolean master;
    boolean main;
    boolean coef;
    boolean post;
    boolean inputctl;
    boolean marker;
    boolean entropy;
    boolean idct;
    boolean upsample;
    boolean cconvert;
    boolean cquantize;
};

/* Function declarations */
struct jpeg_error_mgr *jpeg_std_error(struct jpeg_error_mgr *err);

void jpeg_create_decompress(j_decompress_ptr cinfo);
void jpeg_destroy_decompress(j_decompress_ptr cinfo);
void jpeg_abort_decompress(j_decompress_ptr cinfo);

void jpeg_mem_src(j_decompress_ptr cinfo, const unsigned char *inbuffer, unsigned long insize);
void jpeg_stdio_src(j_decompress_ptr cinfo, FILE *infile);

int jpeg_read_header(j_decompress_ptr cinfo, boolean require_image);
boolean jpeg_start_decompress(j_decompress_ptr cinfo);
JDIMENSION jpeg_read_scanlines(j_decompress_ptr cinfo, JSAMPARRAY scanlines, JDIMENSION max_lines);
boolean jpeg_finish_decompress(j_decompress_ptr cinfo);

/* Return codes */
#define JPEG_HEADER_OK          0
#define JPEG_HEADER_TABLES_ONLY 1
#define JPEG_SUSPENDED          2

#ifdef __cplusplus
}
#endif

#endif /* JPEGLIB_H */