#ifndef SSD1306_H__
#define SSD1306_H__

#include <stdbool.h>
#include <stdint.h>

#ifndef SSD1306_I2C_ADDR
#define SSD1306_I2C_ADDR 0x3c
#endif

#ifndef SSD1306_WIDTH
#define SSD1306_WIDTH 128
#endif

#ifndef SSD1306_HEIGHT
#define SSD1306_HEIGHT 32
#endif

extern bool ssd1306_init(void);
extern bool ssd1306_display_on(void);
extern bool ssd1306_display_off(void);
extern bool ssd1306_write_bitmap(const uint8_t *data, unsigned len);
extern bool ssd1306_clear(void);
extern bool ssd1306_hbitmap(unsigned page0, unsigned col0, unsigned npages,
			    unsigned ncols, const uint8_t *data);
extern bool ssd1306_set_start_line(unsigned n);
extern bool ssd1306_set_display_offset(unsigned n);
extern bool ssd1306_hscroll(bool left, unsigned start_page, unsigned end_page,
			    unsigned speed);

#endif /* SSD1306_H__ */

