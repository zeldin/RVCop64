#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include <libbase/i2c.h>

#include "ssd1306.h"

/* Commands */
#define SSD1306_SETLOWCOLUMN 0x00
#define SSD1306_SETHIGHCOLUMN 0x10
#define SSD1306_MEMORYMODE 0x20
#define SSD1306_COLUMNADDR 0x21
#define SSD1306_PAGEADDR 0x22
#define SSD1306_RIGHT_HORIZONTAL_SCROLL 0x26
#define SSD1306_LEFT_HORIZONTAL_SCROLL 0x27
#define SSD1306_VERTICAL_AND_RIGHT_HORIZONTAL_SCROLL 0x29
#define SSD1306_VERTICAL_AND_LEFT_HORIZONTAL_SCROLL 0x2A
#define SSD1306_DEACTIVATE_SCROLL 0x2E
#define SSD1306_ACTIVATE_SCROLL 0x2F
#define SSD1306_SETSTARTLINE 0x40
#define SSD1306_SETCONTRAST 0x81
#define SSD1306_CHARGEPUMP 0x8D
#define SSD1306_SEGREMAP 0xA0
#define SSD1306_SET_VERTICAL_SCROLL_AREA 0xA3
#define SSD1306_DISPLAYALLON_RESUME 0xA4
#define SSD1306_DISPLAYALLON 0xA5
#define SSD1306_NORMALDISPLAY 0xA6
#define SSD1306_INVERTDISPLAY 0xA7
#define SSD1306_SETMULTIPLEX 0xA8
#define SSD1306_DISPLAYOFF 0xAE
#define SSD1306_DISPLAYON 0xAF
#define SSD1306_COMSCANINC 0xC0
#define SSD1306_COMSCANDEC 0xC8
#define SSD1306_SETDISPLAYOFFSET 0xD3
#define SSD1306_SETDISPLAYCLOCKDIV 0xD5
#define SSD1306_SETPRECHARGE 0xD9
#define SSD1306_SETCOMPINS 0xDA
#define SSD1306_SETVCOMDETECT 0xDB

static const uint8_t ssd1306_initcmd[] = {
  SSD1306_DISPLAYOFF,
  SSD1306_SETDISPLAYCLOCKDIV, 0x80,
  SSD1306_SETMULTIPLEX, SSD1306_HEIGHT-1,
  SSD1306_SETDISPLAYOFFSET, 0,
  SSD1306_SETSTARTLINE | 0,
  SSD1306_CHARGEPUMP, 0x14,
  SSD1306_MEMORYMODE, 0,
  SSD1306_SEGREMAP | 0x1,
  SSD1306_COMSCANDEC,
  SSD1306_SETCOMPINS, 0x02,
  SSD1306_SETCONTRAST, 0x8f,
  SSD1306_SETPRECHARGE, 0xf1,
  SSD1306_SETVCOMDETECT, 0x40,
  SSD1306_DISPLAYALLON_RESUME,
  SSD1306_NORMALDISPLAY,
  SSD1306_DEACTIVATE_SCROLL,
  SSD1306_SET_VERTICAL_SCROLL_AREA, 0, SSD1306_HEIGHT,
  SSD1306_PAGEADDR, 0, 0xff,
  SSD1306_COLUMNADDR, 0, SSD1306_WIDTH-1,
};

static bool ssd1306_cmd(uint8_t cmd)
{
  return i2c_write(SSD1306_I2C_ADDR, 0, &cmd, 1, 1);
}

bool ssd1306_write_bitmap(const uint8_t *data, unsigned len)
{
  return i2c_write(SSD1306_I2C_ADDR, 0x40, data, len, 1);
}

bool ssd1306_init(void)
{
  return i2c_write(SSD1306_I2C_ADDR, 0, ssd1306_initcmd, sizeof(ssd1306_initcmd), 1);
}

bool ssd1306_display_on(void)
{
  return ssd1306_cmd(SSD1306_DISPLAYON);
}

bool ssd1306_display_off(void)
{
  return ssd1306_cmd(SSD1306_DISPLAYOFF);
}

bool ssd1306_clear(void)
{
  uint8_t zeros[SSD1306_WIDTH];
  uint8_t cmd[] = {
    SSD1306_MEMORYMODE, 0,
    SSD1306_PAGEADDR, 0, 0xff,
    SSD1306_COLUMNADDR, 0, SSD1306_WIDTH-1,
  };
  unsigned i;
  memset(zeros, 0, sizeof(zeros));
  if (!i2c_write(SSD1306_I2C_ADDR, 0, cmd, sizeof(cmd), 1))
    return false;
  for (i=0; i<8; i++)
    if (!ssd1306_write_bitmap(zeros, sizeof(zeros)))
      return false;
  return true;
}

bool ssd1306_hbitmap(unsigned page0, unsigned col0, unsigned npages,
		     unsigned ncols, const uint8_t *data)
{
  uint8_t cmd[] = {
    SSD1306_MEMORYMODE, 0,
    SSD1306_PAGEADDR, page0, page0+npages-1,
    SSD1306_COLUMNADDR, col0, col0+ncols-1,
  };
  return i2c_write(SSD1306_I2C_ADDR, 0, cmd, sizeof(cmd), 1) &&
    ssd1306_write_bitmap(data, npages*ncols);
}

bool ssd1306_set_start_line(unsigned n)
{
  return ssd1306_cmd(SSD1306_SETSTARTLINE | (n & 0x3f));
}

bool ssd1306_set_display_offset(unsigned n)
{
  uint8_t cmd[] = {
    SSD1306_SETDISPLAYOFFSET, n
  };
  return i2c_write(SSD1306_I2C_ADDR, 0, cmd, sizeof(cmd), 1);
}

bool ssd1306_hscroll(bool left, unsigned start_page, unsigned end_page,
		     unsigned speed)
{
  uint8_t cmd[] = {
    SSD1306_DEACTIVATE_SCROLL,
    (left? SSD1306_LEFT_HORIZONTAL_SCROLL : SSD1306_RIGHT_HORIZONTAL_SCROLL),
    0, start_page, speed, end_page, 0, 0xff,
    SSD1306_ACTIVATE_SCROLL
  };
  return i2c_write(SSD1306_I2C_ADDR, 0, cmd, sizeof(cmd), 1);
}
