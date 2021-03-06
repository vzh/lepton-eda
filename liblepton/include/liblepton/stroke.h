/* Lepton EDA library
 * Copyright (C) 1998-2010 Ales Hvezda
 * Copyright (C) 1998-2015 gEDA Contributors
 * Copyright (C) 2017-2021 Lepton EDA Contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/*! \file stroke.h
 *
 *  \brief Line stroke style of objects such as arcs, boxes, circles, and lines.
 */

G_BEGIN_DECLS

enum _LeptonStrokeCapType
{
  END_NONE,
  END_SQUARE,
  END_ROUND
};

typedef enum _LeptonStrokeCapType LeptonStrokeCapType;

enum _LeptonStrokeType
{
  TYPE_SOLID,
  TYPE_DOTTED,
  TYPE_DASHED,
  TYPE_CENTER,
  TYPE_PHANTOM
};

typedef enum _LeptonStrokeType LeptonStrokeType;


typedef struct _LeptonStroke LeptonStroke;

struct _LeptonStroke
{
  LeptonStrokeType type;
  LeptonStrokeCapType cap_type;
  int width;
  int dash_length;
  int space_length;
};

LeptonStroke*
lepton_stroke_new ();

void
lepton_stroke_free (LeptonStroke * stroke);

LeptonStrokeType
lepton_stroke_get_type (const LeptonStroke *stroke);

void
lepton_stroke_set_type (LeptonStroke *stroke,
                        LeptonStrokeType type);
LeptonStrokeCapType
lepton_stroke_get_cap_type (const LeptonStroke *stroke);

void
lepton_stroke_set_cap_type (LeptonStroke *stroke,
                            LeptonStrokeCapType cap_type);
int
lepton_stroke_get_width (const LeptonStroke *stroke);

void
lepton_stroke_set_width (LeptonStroke *stroke,
                         int width);
int
lepton_stroke_get_dash_length (const LeptonStroke *stroke);

void
lepton_stroke_set_dash_length (LeptonStroke *stroke,
                               int dash_length);
int
lepton_stroke_get_space_length (const LeptonStroke *stroke);

void
lepton_stroke_set_space_length (LeptonStroke *stroke,
                                int space_length);

/* Helpers for Scheme. */
const char*
lepton_stroke_cap_type_to_string (LeptonStrokeCapType cap_type);

LeptonStrokeCapType
lepton_stroke_cap_type_from_string (char *s);

const char*
lepton_stroke_type_to_string (LeptonStrokeType cap_type);

LeptonStrokeType
lepton_stroke_type_from_string (char *s);

G_END_DECLS
