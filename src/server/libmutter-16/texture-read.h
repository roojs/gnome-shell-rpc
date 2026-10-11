#pragma once
#include <cogl/cogl.h>
#include <stdint.h>

static inline int
gsr_texture_read (CoglTexture *texture, uint8_t *data, unsigned rowstride)
{
	return cogl_texture_get_data (texture,
		COGL_PIXEL_FORMAT_CAIRO_ARGB32_COMPAT,
		rowstride,
		data);
}

static inline int
gsr_texture_readable (CoglTexture *texture)
{
	return cogl_texture_is_get_data_supported (texture);
}

static inline int
gsr_texture_width (CoglTexture *texture)
{
	return cogl_texture_get_width (texture);
}

static inline int
gsr_texture_height (CoglTexture *texture)
{
	return cogl_texture_get_height (texture);
}
