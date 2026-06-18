/* Lepton EDA attribute editor
 * Copyright (C) 2003-2010 Stuart D. Brorson.
 * Copyright (C) 2003-2013 gEDA Contributors
 * Copyright (C) 2017-2026 Lepton EDA Contributors
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
/*------------------------------------------------------------------*/
/*! \file
 * \brief Functions to manipulate attribute visibility
 *
 * This file holds widgets and functions used in conjunction
 * with setting attribute visibility.
 * \todo There seems to be a lot of duplicated code in this file -
 *       a good candidate for refactoring.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

/*------------------------------------------------------------------
 * Includes required to run graphical widgets.
 *------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include <gtk/gtk.h>
#include <gdk/gdk.h>
#include <gdk/gdkkeysyms.h>

#include <glib.h>
#include <glib-object.h>

#include <sys/types.h>

#ifdef HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif

#include <sys/stat.h>

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifdef HAVE_STRING_H
#include <string.h>
#endif


/*------------------------------------------------------------------
 * Gattrib specific includes
 *------------------------------------------------------------------*/
#include <liblepton/liblepton.h>
#include "../include/struct.h"     /* typdef and struct declarations */
#include "../include/prototype.h"  /* function prototypes */
#include "../include/globals.h"


/* ----- s_visibility stuff begins here ----- */



/* ---------------------------------------------------------------------- */
/* \brief Set the selected cells to INVISIBLE
 *
 *
 * This sets the selected cells to INVISIBLE.
 * This function is called from the menu, it assumes you have
 * selected a range of cells which are carried in the global
 * variable "sheet".
 */
void
s_visibility_set_invisible (int cur_page)
{
  gint i, j;
  gint row_start, row_end, col_start, col_end;
  GtkSheet *sheet;
  GtkSheetRange range;
  GtkSheetState state;
  gboolean result;
  gboolean multiple_selection;
  int active_cell_row, active_cell_column;

  sheet = attrib_get_sheet (cur_page);

  g_return_if_fail (sheet != NULL);
  g_return_if_fail (GTK_IS_SHEET (sheet));

  multiple_selection = attrib_sheet_multiple_selection (sheet);

  result = gtk_sheet_get_selection (sheet, &state, &range);

  if (multiple_selection)
  {
    g_debug ("s_visibility_set_invisible: Range/col/row selected.\n");

    row_start = range.row0;
    row_end = range.rowi;
    col_start = range.col0;
    col_end = range.coli;
    for (i=row_start; i<=row_end; i++) {
      for (j=col_start; j<=col_end; j++) {
        /* first set cell in SHEET_DATA to invisible */
        s_visibility_set_cell(cur_page, i, j,
                              INVISIBLE,
                              LEAVE_NAME_VALUE_ALONE);
        /* Now set cell in gtksheet to desired color */
        /* Color names are defined
         * in liblepton/include/colors.h */
        x_gtksheet_set_cell_text_color(sheet, i, j, GREY);

      }
    }
    /* Now return sheet to normal -- unselect range */
    gtk_sheet_unselect_range (sheet);
  }
  else
  {
    g_debug ("s_visibility_set_invisible: Normal selection.\n");

    gtk_sheet_get_active_cell (sheet, &active_cell_row, &active_cell_column);
    s_visibility_set_cell(cur_page,
                          active_cell_row,
                          active_cell_column,
                          INVISIBLE,
                          LEAVE_NAME_VALUE_ALONE);

    x_gtksheet_set_cell_text_color(sheet,
                                   active_cell_row,
                                   active_cell_column,
                                   GREY);
  }
}

/* ---------------------------------------------------------------------- */
/*! \brief Set the visibility of the selected cells to NAME_ONLY.
 *
 * This sets the selected cells to NAME_ONLY.
 * This function is invoked from the menu, it assumes you have
 * selected a range of cells which are carried in the global
 * variable "sheet".
 */
void
s_visibility_set_name_only (int cur_page)
{
  gint i, j;
  gint row_start, row_end, col_start, col_end;
  GtkSheet *sheet;
  GtkSheetRange range;
  GtkSheetState state;
  gboolean result;
  gboolean multiple_selection;
  int active_cell_row, active_cell_column;

  sheet = attrib_get_sheet (cur_page);

  g_return_if_fail (sheet != NULL);
  g_return_if_fail (GTK_IS_SHEET (sheet));

  multiple_selection = attrib_sheet_multiple_selection (sheet);

  result = gtk_sheet_get_selection (sheet, &state, &range);

  if (multiple_selection)
  {
    g_debug ("s_visibility_set_name_only: Range/col/row selected.\n");
    row_start = range.row0;
    row_end = range.rowi;
    col_start = range.col0;
    col_end = range.coli;
    for (i=row_start; i<=row_end; i++) {
      for (j=col_start; j<=col_end; j++) {
        s_visibility_set_cell(cur_page, i, j, VISIBLE, SHOW_NAME);
        /* Color names are defined
         * in liblepton/include/colors.h */
        x_gtksheet_set_cell_text_color(sheet, i, j, RED);

      }
    }
    /* Now return sheet to normal -- unselect range */
    gtk_sheet_unselect_range (sheet);
  }
  else
  {
    gtk_sheet_get_active_cell (sheet, &active_cell_row, &active_cell_column);
    s_visibility_set_cell(cur_page,
                          active_cell_row,
                          active_cell_column,
                          VISIBLE, SHOW_NAME);
    x_gtksheet_set_cell_text_color(sheet,
                                   active_cell_row,
                                   active_cell_column,
                                   RED);
  }
}

/* ---------------------------------------------------------------------- */
/* \brief Set the selected cells' visibility to VALUE_ONLY
 *
 * s_visibility_set_value_only -- This sets the selected cells to VALUE_ONLY.
 * This fcn is invoked from the menu, it assumes you have
 * selected a range of cells which are carried in the global
 * variable "sheet".
 */
void
s_visibility_set_value_only (int cur_page)
{
  gint i, j;
  gint row_start, row_end, col_start, col_end;
  GtkSheet *sheet;
  GtkSheetRange range;
  GtkSheetState state;
  gboolean result;
  gboolean multiple_selection;
  int active_cell_row, active_cell_column;

  sheet = attrib_get_sheet (cur_page);

  g_return_if_fail (sheet != NULL);
  g_return_if_fail (GTK_IS_SHEET (sheet));

  multiple_selection = attrib_sheet_multiple_selection (sheet);

  result = gtk_sheet_get_selection (sheet, &state, &range);

  if (multiple_selection)
  {
    g_debug ("s_visibility_set_value_only: Range/col/row selected.\n");
    row_start = range.row0;
    row_end = range.rowi;
    col_start = range.col0;
    col_end = range.coli;
    for (i=row_start; i<=row_end; i++) {
      for (j=col_start; j<=col_end; j++) {
        s_visibility_set_cell(cur_page, i, j, VISIBLE, SHOW_VALUE);
        /* Color names are defined
         * in liblepton/include/colors.h */
        x_gtksheet_set_cell_text_color(sheet, i, j, BLACK);

      }
    }
    /* Now return sheet to normal -- unselect range */
    gtk_sheet_unselect_range (sheet);
  }
  else
  {
    g_debug ("s_visibility_set_value_only: Sheet normal selected.\n");

    gtk_sheet_get_active_cell (sheet, &active_cell_row, &active_cell_column);
    s_visibility_set_cell(cur_page,
                          active_cell_row,
                          active_cell_column,
                          VISIBLE, SHOW_VALUE);
    x_gtksheet_set_cell_text_color(sheet,
                                   active_cell_row,
                                   active_cell_column,
                                   BLACK);
  }
}

/* ---------------------------------------------------------------------- */
/* \brief Set the visibility of the selected cells to NAME_AND_VALUE
 *
 * This sets the selected cells
 * to NAME_AND_VALUE
 * This fcn is invoked from the menu, it assumes you have
 * selected a range of cells which are carried in the global
 * variable "sheet".
 *
 */
void
s_visibility_set_name_and_value (int cur_page)
{
  gint i, j;
  gint row_start, row_end, col_start, col_end;
  GtkSheet *sheet;
  GtkSheetRange range;
  GtkSheetState state;
  gboolean result;
  gboolean multiple_selection;
  int active_cell_row, active_cell_column;

  sheet = attrib_get_sheet (cur_page);

  g_return_if_fail (sheet != NULL);
  g_return_if_fail (GTK_IS_SHEET (sheet));

  multiple_selection = attrib_sheet_multiple_selection (sheet);

  result = gtk_sheet_get_selection (sheet, &state, &range);

  if (multiple_selection)
  {
    row_start = range.row0;
    row_end = range.rowi;
    col_start = range.col0;
    col_end = range.coli;
    for (i=row_start; i<=row_end; i++) {
      for (j=col_start; j<=col_end; j++) {
        s_visibility_set_cell(cur_page, i, j, VISIBLE, SHOW_NAME_VALUE);
        /* Color names are defined
         * in liblepton/include/colors.h */
        x_gtksheet_set_cell_text_color(sheet, i, j, BLUE);

      }
    }
    /* Now return sheet to normal -- unselect range */
    gtk_sheet_unselect_range (sheet);
  }
  else
  {
    gtk_sheet_get_active_cell (sheet, &active_cell_row, &active_cell_column);
    s_visibility_set_cell(cur_page,
                          active_cell_row,
                          active_cell_column,
                          VISIBLE,
                          SHOW_NAME_VALUE);
    x_gtksheet_set_cell_text_color(sheet,
                                   active_cell_row,
                                   active_cell_column,
                                   BLUE);
  }
}


/* ==================  Private functions  =================== */

/* ---------------------------------------------------------------------- */
/* \brief set the visibility of an individual cell
 *
 * Set the visibility of an individual cell
 * to "state".  The cell is identified by (row, col)
 * \param cur_page index of spreadsheet tab
 * \param row Row index of target cell
 * \param col Column index of target cell
 * \param visibility Visibility value to set cell to
 * \param show_name_value Name, Value visibility flag
 */
void s_visibility_set_cell(gint cur_page, gint row, gint col,
                           gint visibility,
                           gint show_name_value) {
  TABLE **local_table = NULL;

  g_debug ("s_visibility_set_cell: Setting row = %d, col = %d.\n",
           row, col);

  switch (cur_page) {

  case 0:
    local_table = sheet_head->component_table;
    break;

  case 1:
    local_table = sheet_head->net_table;
    break;

  case 2:
    local_table = sheet_head->pin_table;
    break;
  }

  if ((row != -1) && ( col != -1))
  {
    /* Question:  how to sanity check (row, col) selection? */
    local_table[row][col].visibility = visibility;
    /* cell has been updated.  */
    s_sheet_data_set_changed (sheet_head, TRUE);

    if (show_name_value != LEAVE_NAME_VALUE_ALONE) {
      local_table[row][col].show_name_value = show_name_value;
      /* cell has been updated.  */
      s_sheet_data_set_changed (sheet_head, TRUE);
    }
  }
}
