/*
 * Copyright 2024 Matt Evans
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation files
 * (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef UMAC_H
#define UMAC_H

#include "disc.h"
#include "via.h"
#include "machw.h"

int     umac_init(void *_ram_base, void *_rom_base, disc_descr_t discs[DISC_NUM_DRIVES]);
int     umac_loop(void);
void    umac_reset(void);
void    umac_opt_disassemble(int enable);
void    umac_mouse(int deltax, int deltay, int button);
void    umac_kbd_event(uint8_t scancode, int down);

static inline void      umac_vsync_event(void)
{
        via_caX_event(2);
}

static inline void      umac_1hz_event(void)
{
        via_caX_event(1);
}

/* Return the offset into RAM of the current display buffer */
static inline unsigned int      umac_get_fb_offset(void)
{
        /* FIXME: Implement VIA RA6/vid.pg2 */
        return RAM_SIZE - ((DISP_WIDTH * DISP_HEIGHT / 8) + 0x380);
}

/* Audio.  The Mac Plus plays sound by DMA from a 370-word buffer near the
 * top of RAM, one word per scanline, so one buffer is consumed per video
 * frame (~60.15Hz, i.e. ~22.25kHz).  The sample is the high byte of each
 * word (0x80 = silence); the low byte is the floppy motor PWM and unused.
 *
 * Call umac_audio_get_frame() once per vsync (just before or after
 * umac_vsync_event()).  It copies the current buffer's 370 unsigned 8-bit
 * samples to out[], and returns the VIA volume setting (0-7) in *volume.
 * Returns 0 if the Mac currently has sound disabled (out[] is then untouched).
 */
#define UMAC_AUDIO_SAMPLES      370

extern uint8_t umac_snd_volume, umac_snd_main_buf, umac_snd_off;

static inline int       umac_audio_get_frame(uint8_t *out, uint8_t *volume)
{
        if (umac_snd_off)
                return 0;
        unsigned int base = RAM_SIZE - 0x300;
        if (!umac_snd_main_buf)
                base -= 0x5C00;
        const uint8_t *p = _ram_base + base;
        for (unsigned int i = 0; i < UMAC_AUDIO_SAMPLES; i++)
                out[i] = p[i * 2];
        *volume = umac_snd_volume;
        return 1;
}

#endif
