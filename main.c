/*!
 *  \brief     Interactive console interface between an user and the function for drawing triangles (in assembly).
 *  \author    Dawid Sygocki
 *  \date      2020-05-15
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>
#include <stdbool.h>
#include <ctype.h>

//maximal path length for compatibility with MS Windows
//see https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file#maximum-path-length-limitation
#define MAX_PATH 260

#define BUF_SIZE 512

typedef uint8_t BYTE;
typedef int16_t SHORT;
typedef uint16_t WORD;
typedef int32_t LONG;
typedef uint32_t DWORD;

/*! \brief Bitmap header containing image specification.

    For detailed description see https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfoheader
 */
typedef struct BITMAPINFOHEADER {
    DWORD biSize;
    LONG  biWidth;
    LONG  biHeight;
    WORD  biPlanes;
    WORD  biBitCount;
    DWORD biCompression;
    DWORD biSizeImage;
    LONG  biXPelsPerMeter;
    LONG  biYPelsPerMeter;
    DWORD biClrUsed;
    DWORD biClrImportant;
} BITMAPINFOHEADER;

/*! \brief Describes XY position and RGB color of a vertex.
 */
typedef struct VERTEXDATA {
    LONG posX;
    LONG posY;
    BYTE colR;
    BYTE colG;
    BYTE colB;
} VERTEXDATA;

/*! \brief Generates the BITMAPFILEHEADER structure in the form of array.

    For detailed description see https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapfileheader

    \param header Pointer to a 14-bytes long array for storing the result.
    \param file_size Size of the bitmap file (in bytes).
    \param headers_length The offset from the beginning of the file to the bitmap color data (in bytes).
 */
void set_file_header(BYTE (*header)[14], const DWORD file_size, const DWORD headers_length)
{
    if (header != NULL) {
        (*header)[0] = 'B';
        (*header)[1] = 'M';
        memcpy(&(*header)[2], &file_size, 4);
        memset(&(*header)[6], 0, 4);
        memcpy(&(*header)[10], &headers_length, 4);
    }
}

/*! \brief Sets up the #BITMAPINFOHEADER structure.

    \param header Pointer to the structure.
    \param width Width of the bitmap.
    \param height Height of the bitmap.
 */
void set_info_header(BITMAPINFOHEADER *header, const LONG width, const LONG height)
{
    if (header != NULL) {
        DWORD stride = (abs(width) * 3 + 3) & 0xfffffffc;
        header->biSize = sizeof(*header);
        header->biWidth = width;
        header->biHeight = height;
        header->biPlanes = 1;
        header->biBitCount = 24;
        header->biCompression = 0;
        header->biSizeImage = abs(height) * stride;
        header->biXPelsPerMeter = 0;
        header->biYPelsPerMeter = 0;
        header->biClrUsed = 0;
        header->biClrImportant = 0;
    }
}

/*! \brief Sets up the #VERTEXDATA structure.

    \param pos_x Horizontal position of the vertex.
    \param pos_y Vertical position of the vertex.
    \param col_r Intensity of red in the vertex color.
    \param col_g Intensity of green in the vertex color.
    \param col_b Intensity of blue in the vertex color.
 */
void set_vertex(VERTEXDATA *vertex, const LONG pos_x, const LONG pos_y, const BYTE col_r, const BYTE col_g, const BYTE col_b)
{
    if (vertex != NULL) {
        vertex->posX = pos_x;
        vertex->posY = pos_y;
        vertex->colR = col_r;
        vertex->colG = col_g;
        vertex->colB = col_b;
    }
}

/*! \brief Paints the bitmap using the given color.

    \param image_data Pointer to the bitmap data.
    \param info_header Pointer to the BITMAPINFOHEADER describing the bitmap.
    \param red Intensity of red in desired color.
    \param green Intensity of green in desired color.
    \param blue Intensity of blue in desired color.
 */
void clear_bitmap(BYTE *image_data, BITMAPINFOHEADER *info_header, const BYTE red, const BYTE green, const BYTE blue)
{
    if (image_data != NULL && info_header != NULL) {
        DWORD stride = (abs(info_header->biWidth) * 3 + 3) & 0xfffffffc;
        for (DWORD i = 0; i < abs(info_header->biWidth); i++) {
            (image_data + i * 3)[0] = blue;
            (image_data + i * 3)[1] = green;
            (image_data + i * 3)[2] = red;
        }
        for (DWORD i = 1; i < abs(info_header->biHeight); i++) {
            memcpy(image_data + i * stride, image_data, stride);
        }
    }
}

/*! \brief Swaps two VERTEXDATA structures.

    \param a Pointer to the first structure.
    \param b Pointer to the second structure.
 */
void swap_vertices(VERTEXDATA *a, VERTEXDATA *b)
{
    if (a != NULL && b != NULL) {
        VERTEXDATA tmp;
        memcpy(&tmp, a, sizeof(VERTEXDATA));
        memcpy(a, b, sizeof(VERTEXDATA));
        memcpy(b, &tmp, sizeof(VERTEXDATA));
    }
}

/*! \brief Sorts an array of three vertices by their vertical and then horizontal position (ascending).

    \param vertex_data Pointer to an array of three VERTEXDATA structures.
 */
void sort_triangle_vertices(VERTEXDATA (*vertex_data)[3])
{
    if (vertex_data != NULL) {
        if ((*vertex_data)[1].posY < (*vertex_data)[0].posY) {
            swap_vertices(&(*vertex_data)[0], &(*vertex_data)[1]);
        }
        if ((*vertex_data)[2].posY < (*vertex_data)[1].posY) {
            swap_vertices(&(*vertex_data)[1], &(*vertex_data)[2]);
        }
        if ((*vertex_data)[1].posY < (*vertex_data)[0].posY) {
            swap_vertices(&(*vertex_data)[0], &(*vertex_data)[1]);
        }
    }
}

/*! \brief Draws a triangle on the bitmap.

    \param image_data Pointer to the bitmap data.
    \param info_header Pointer to the BITMAPINFOHEADER describing the bitmap.
    \param vertex_data Pointer to the sorted array of three VERTEXDATA structures describing a triangle.
        The array has to be sorted by vertical position in ascending order.
    \see sort_triangle_vertices

    \return Zero on success, -1 if any argument is a null pointer.
 */
LONG draw_triangle(BYTE *image_data, BITMAPINFOHEADER *info_header, VERTEXDATA (*vertices)[3])
{
    if (image_data == NULL || info_header == NULL || vertices == NULL) {
        return -1;
    }
    
    struct VERTEXSTEP {
        float x, r, g, b;
    } step[3] = {{}, {}, {}};
    if ((*vertices)[0].posY != (*vertices)[1].posY) {
        float difference = (*vertices)[0].posY - (*vertices)[1].posY;
        step[0].x = ((*vertices)[0].posX - (*vertices)[1].posX) / difference;
        step[0].r = ((*vertices)[0].colR - (*vertices)[1].colR) / difference;
        step[0].g = ((*vertices)[0].colG - (*vertices)[1].colG) / difference;
        step[0].b = ((*vertices)[0].colB - (*vertices)[1].colB) / difference;
    }
    if ((*vertices)[0].posY != (*vertices)[2].posY) {
        float difference = (*vertices)[0].posY - (*vertices)[2].posY;
        step[1].x = ((*vertices)[0].posX - (*vertices)[2].posX) / difference;
        step[1].r = ((*vertices)[0].colR - (*vertices)[2].colR) / difference;
        step[1].g = ((*vertices)[0].colG - (*vertices)[2].colG) / difference;
        step[1].b = ((*vertices)[0].colB - (*vertices)[2].colB) / difference;
    }
    if ((*vertices)[1].posY != (*vertices)[2].posY) {
        float difference = (*vertices)[1].posY - (*vertices)[2].posY;
        step[2].x = ((*vertices)[1].posX - (*vertices)[2].posX) / difference;
        step[2].r = ((*vertices)[1].colR - (*vertices)[2].colR) / difference;
        step[2].g = ((*vertices)[1].colG - (*vertices)[2].colG) / difference;
        step[2].b = ((*vertices)[1].colB - (*vertices)[2].colB) / difference;
    }

    size_t stride = (abs(info_header->biWidth) * 3 + 3) & 0xfffffffc;
    LONG min_y = (*vertices)[0].posY, max_y = (*vertices)[2].posY;
    if (min_y < 0) {
        min_y = 0;
    }
    if (max_y >= abs(info_header->biHeight)) {
        max_y = abs(info_header->biHeight) - 1;
    }

    for (LONG i = min_y; i <= max_y; i++) {
        struct VERTEXDATA left = {}, right = {};
        if (i < (*vertices)[1].posY) {
            left.posX = round((*vertices)[0].posX + (i - (*vertices)[0].posY) * step[0].x);
            left.colR = round((*vertices)[0].colR + (i - (*vertices)[0].posY) * step[0].r);
            left.colG = round((*vertices)[0].colG + (i - (*vertices)[0].posY) * step[0].g);
            left.colB = round((*vertices)[0].colB + (i - (*vertices)[0].posY) * step[0].b);
        } else {
            left.posX = round((*vertices)[1].posX + (i - (*vertices)[1].posY) * step[2].x);
            left.colR = round((*vertices)[1].colR + (i - (*vertices)[1].posY) * step[2].r);
            left.colG = round((*vertices)[1].colG + (i - (*vertices)[1].posY) * step[2].g);
            left.colB = round((*vertices)[1].colB + (i - (*vertices)[1].posY) * step[2].b);
        }
        right.posX = round((*vertices)[0].posX + (i - (*vertices)[0].posY) * step[1].x);
        right.colR = round((*vertices)[0].colR + (i - (*vertices)[0].posY) * step[1].r);
        right.colG = round((*vertices)[0].colG + (i - (*vertices)[0].posY) * step[1].g);
        right.colB = round((*vertices)[0].colB + (i - (*vertices)[0].posY) * step[1].b);
        if (left.posX > right.posX) {
            swap_vertices(&left, &right);
        }
        struct COLORSTEP {
            float r, g, b;
        } line_color_step = {};
        if (left.posX != right.posX) {
            float difference = left.posX - right.posX;
            line_color_step.r = ((SHORT)left.colR - right.colR) / difference;
            line_color_step.g = ((SHORT)left.colG - right.colG) / difference;
            line_color_step.b = ((SHORT)left.colB - right.colB) / difference;
        }
        LONG min_x = left.posX, max_x = right.posX;
        if (min_x < 0) {
            min_x = 0;
        }
        if (max_x >= abs(info_header->biWidth)) {
            max_x = abs(info_header->biWidth) - 1;
        }
        for (LONG j = min_x; j <= max_x; j++) {
            BYTE *pixel_address = image_data + i * stride + j * 3;
            pixel_address[0] = left.colB + (j - left.posX) * line_color_step.b;
            pixel_address[1] = left.colG + (j - left.posX) * line_color_step.g;
            pixel_address[2] = left.colR + (j - left.posX) * line_color_step.r;
        }
    }
    return 0;
}

/*! \brief Prints intoduction to the console interface.
 */
void print_help(void)
{
    puts("[Interactive RGB triangle drawing]");
    puts("Use one of the following commands:");
    puts("  help             prints this message");
    puts("  draw vertices    draws specified triangle on the bitmap");
    puts("                    the format of vertices is straightforward:");
    puts("                    x1 y1 color1 x2 y2 color2 x3 y3 color3");
    puts("  clear [color]    clears the bitmap (the default color is white)");
    puts("  save [filename]  saves the bitmap to a file");
    puts("  kill             quits the program without saving");
    puts("  quit             quits the program saving bitmap to the default location\n");
    puts("Supported color formats:");
    puts("  #rrggbb          (hexadecimal, 00-ff each)");
    puts("  red green blue   (decimal, 0-255 each)\n");
    puts("Examples:");
    puts("  draw 15 5 #000000 5 10 #000000 25 15 #000000");
    puts("  clear 255 0 0");
    puts("  save triangle.bmp\n");
}

/*! \brief Saves the bitmap to a file.

    \param file_header Pointer to the BITMAPFILEHEADER (in the form of byte array) describing the output file.
    \param info_header Pointer to the BITMAPINFOHEADER describing the bitmap.
    \param image_data Pointer to the bitmap data.
    \param output_filename Output filename.

    \return Zero on success, -1 if any argument is a null pointer, -2 on file I/O error.
 */
LONG save_bitmap(BYTE (*file_header)[14], BITMAPINFOHEADER *info_header, BYTE *image_data, const char *output_filename)
{
    if (file_header != 0 && info_header != 0 && image_data != 0 && output_filename != 0) {
        FILE *output_file = fopen(output_filename, "wb");
        if (output_file == NULL) {
            return -2;
        }
        //write BITMAPFILEHEADER
        DWORD bytes_to_write = sizeof(*file_header),
            bytes_written = 0;
        bytes_written = fwrite(file_header, 1, bytes_to_write, output_file);
        if (bytes_to_write != bytes_written) {
            fclose(output_file);
            return -2;
        }
        //write BITMAPINFOHEADER
        bytes_to_write = sizeof(*info_header);
        bytes_written = fwrite(info_header, 1, bytes_to_write, output_file);
        if (bytes_to_write != bytes_written) {
            fclose(output_file);
            return -2;
        }
        //write bitmap data
        bytes_to_write = info_header->biSizeImage;
        bytes_written = fwrite(image_data, 1, bytes_to_write, output_file);
        fclose(output_file);
        if (bytes_to_write != bytes_written) {
            return -2;
        }
        return 0;
    } else {
        return -1;
    }
}

int main(int argc, char **argv)
{
    //check if structures size is correct
    if (sizeof(BITMAPINFOHEADER) != 40 || sizeof(VERTEXDATA) > 12) {
        fprintf(stderr, "sizeof(struct BITMAPINFOHEADER) = %u (should be 40)\n", sizeof(BITMAPINFOHEADER));
        fprintf(stderr, "sizeof(struct VERTEXDATA) = %u (should be 12 at most)\n", sizeof(VERTEXDATA));
        fputs("Please use different compiler options in order to meet these criteria!", stderr);
        exit(EXIT_FAILURE);
    }

    //settings
    LONG image_width = 256,
        image_height = 256;
    char output_filename[MAX_PATH] = {0};
    strcpy(output_filename, "result.bmp");
    
    //data-related variables created based on user-defined values
    BYTE file_header[14];
    BITMAPINFOHEADER info_header;
    BYTE *image_data;

    //parsing command-line parameters
    switch (argc) {
        case 1: {
            break;
        }
        case 4: {
            image_width = atoi(argv[2]);
            image_height = atoi(argv[3]);
        }
        case 2: {
            output_filename[0] = 0;
            strncat(output_filename, argv[1], MAX_PATH - 1);
            break;
        }
        default: {
            fputs("Usage: rgb_triangle [output_filename [bitmap_width bitmap_height]]", stderr);
            exit(EXIT_FAILURE);
        }
    }
    puts("Settings:");
    printf("  default output filename: %.*s\n", MAX_PATH, output_filename);
    printf("  bitmap size: %dx%d\n\n", image_width, image_height);

    print_help();

    //setting the data-related variables
    set_info_header(&info_header, image_width, image_height);
    DWORD image_data_size = ((abs(image_width) * 3 + 3) & 0xfffffffc) * abs(image_height);
    DWORD summed_header_size = sizeof(file_header) + sizeof(info_header);
    set_file_header(&file_header, image_data_size + summed_header_size, summed_header_size);
    image_data = malloc(image_data_size * sizeof(BYTE));

    //set background
    clear_bitmap(image_data, &info_header, 0xff, 0xff, 0xff);

    char buffer[BUF_SIZE];
    //main loop
    while (true) {
        putchar('>');
        fgets(buffer, BUF_SIZE, stdin);
        buffer[BUF_SIZE - 1] = 0;
        DWORD input_length = strlen(buffer);

        char comparison_buffer[6] = {0, 0, 0, 0, 0, 0};
        if (input_length < 4) {
            puts("Incorrect command!");
            continue;
        }
        memcpy(comparison_buffer, buffer, 4);
        if (input_length > 4) {
            comparison_buffer[4] = buffer[4];
        }
        for (int i = 0; i < 5; i++) {
            if (isspace(comparison_buffer[i])) {
                comparison_buffer[i] = 0;
                break;
            }
        }
        if (strcmp(comparison_buffer, "help") == 0) {
            print_help();
        } else if (strcmp(comparison_buffer, "draw") == 0) {
            bool status_ok = false;
            VERTEXDATA vertex_data[3];
            LONG colors[9];
            LONG values_read = sscanf(buffer, "draw %d %d #%2hhx%2hhx%2hhx %d %d #%2hhx%2hhx%2hhx %d %d #%2hhx%2hhx%2hhx",
                &vertex_data[0].posX, &vertex_data[0].posY, &vertex_data[0].colR, &vertex_data[0].colG,
                &vertex_data[0].colB, &vertex_data[1].posX, &vertex_data[1].posY, &vertex_data[1].colR,
                &vertex_data[1].colG, &vertex_data[1].colB, &vertex_data[2].posX, &vertex_data[2].posY,
                &vertex_data[2].colR, &vertex_data[2].colG, &vertex_data[2].colB);
            if (values_read == 15) {
                status_ok = true;
            } else {
                values_read = sscanf(buffer, "draw %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
                    &vertex_data[0].posX, &vertex_data[0].posY, &colors[0], &colors[1], &colors[2],
                    &vertex_data[1].posX, &vertex_data[1].posY, &colors[3], &colors[4], &colors[5],
                    &vertex_data[2].posX, &vertex_data[2].posY, &colors[6], &colors[7], &colors[8]);
                if (values_read == 15) {
                    status_ok = true;
                    for (DWORD i = 0; i < 9; i++) {
                        if (colors[i] < 0 || colors[i] > 255) {
                            status_ok = false;
                            break;
                        }
                    }
                }
                if (status_ok) {
                    set_vertex(&vertex_data[0], vertex_data[0].posX, vertex_data[0].posY, colors[0], colors[1], colors[2]);
                    set_vertex(&vertex_data[1], vertex_data[1].posX, vertex_data[1].posY, colors[3], colors[4], colors[5]);
                    set_vertex(&vertex_data[2], vertex_data[2].posX, vertex_data[2].posY, colors[6], colors[7], colors[8]);
                }
            }
            if (status_ok) {
                sort_triangle_vertices(&vertex_data);
                if (draw_triangle(image_data, &info_header, &vertex_data) != 0) {
                    puts("Error drawing triangle!");
                }
            } else {
                puts("Incorrect vertex format!");
            }
        } else if (strcmp(comparison_buffer, "clear") == 0) {
            //check for non-whitespace characters after the command
            if (strspn(buffer + 5, " \t\n\v\f\r") + 5 != strlen(buffer)) {
                BYTE red = 255, green = 255, blue = 255;
                LONG values_read = sscanf(buffer, "clear #%2hhx%2hhx%2hhx", &red, &green, &blue);
                if (values_read == 3) {
                    clear_bitmap(image_data, &info_header, red, green, blue);
                } else {
                    bool status_ok = false;
                    LONG colors[3];
                    values_read = sscanf(buffer, "clear %d %d %d", &colors[0], &colors[1], &colors[2]);
                    if (values_read == 3) {
                        status_ok = true;
                        for (DWORD i = 0; i < 3; i++) {
                            if (colors[i] < 0 || colors[i] > 255) {
                                status_ok = false;
                                break;
                            }
                        }
                    }
                    if (status_ok) {
                        clear_bitmap(image_data, &info_header, colors[0], colors[1], colors[2]);
                    } else {
                        puts("Incorrect color format!");
                    }
                }
            } else {
                //no color argument: paint white
                clear_bitmap(image_data, &info_header, 0xff, 0xff, 0xff);
            }
        } else if (strcmp(comparison_buffer, "save") == 0) {
            char *filename = output_filename;
            char filename_buffer[MAX_PATH];
            if (sscanf(buffer, "save %259[^\n]", filename_buffer) == 1) {
                filename = filename_buffer;
            }
            if (save_bitmap(&file_header, &info_header, image_data, filename) == 0) {
                puts("Bitmap saved successfully!");
            } else {
                puts("Error saving bitmap!");
            }
        } else if (strcmp(comparison_buffer, "kill") == 0) {
            break;
        } else if (strcmp(comparison_buffer, "quit") == 0) {
            if (save_bitmap(&file_header, &info_header, image_data, output_filename) == 0) {
                puts("Bitmap saved successfully!");
                break;
            } else {
                puts("Error saving bitmap!");
            }
        } else {
            puts("Incorrect command!");
        }

        if (input_length > 0) {
            input_length--;
            //if the input was too long, skip until the next line
            if (buffer[input_length] != '\n') {
                LONG character = 0;
                while (character != '\n' && character != EOF) {
                    character = getchar();
                }
            }
        }
    }

    //deallocate bitmap data
    free(image_data);

    return 0;
}
