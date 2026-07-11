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
 *  \brief Functions to manipulate the TABLE structure
 *
 * This file holds functions involved in manipulating the TABLE structure,
 * which is subsidiary to SHEET_DATA.  TABLE is a 2 dimensional array
 * of structs; each struct corresponds to the data about an element
 * in a single cell of the spreadsheet.
 * \todo TABLE should also store its dimensions in its own data
 *       structure to save carrying the dimensions around separately.
 */

#include <config.h>

#include <stdio.h>
#ifdef HAVE_STRING_H
#include <string.h>
#endif
#include <math.h>

/*------------------------------------------------------------------
 * Gattrib specific includes
 *------------------------------------------------------------------*/
#include <liblepton/liblepton.h>
#include "../include/struct.h"     /* typdef and struct declarations */
#include "../include/prototype.h"  /* function prototypes */
#include "../include/globals.h"
#include "../include/gettext.h"

/* ===================  Public Functions  ====================== */

/*! \brief Init attrib value associated with a cell.
 *
 *  \par Function Description
 *
 *  Sets initial attrib value associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 */
void
attrib_table_init_attrib_value (TABLE **table,
                                int i,
                                int j)
{
  table[i][j].attrib_value = NULL;
}


/*! \brief Init row name associated with a cell.
 *
 *  \par Function Description
 *
 *  Sets initial row name associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 */
void
attrib_table_init_row_name (TABLE **table,
                            int i,
                            int j)
{
  table[i][j].row_name = NULL;
}


/*! \brief Init column name associated with a cell.
 *
 *  \par Function Description
 *
 *  Sets initial column name associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 */
void
attrib_table_init_column_name (TABLE **table,
                               int i,
                               int j)
{
  table[i][j].col_name = NULL;
}


/*! \brief Create a new table row.
 *
 *  \par Function Description
 *
 *  Allocates and returns a new table row.
 *
 *  \param [in] columns The number of columns in the row.
 */
TABLE*
attrib_table_row_new (int columns)
{
  return (TABLE *) g_malloc (columns * sizeof(TABLE));
}


/*! \brief Get the contents of a table row.
 *
 *  \par Function Description
 *
 *  Returns the contents of a table row.
 *
 *  \param [in] table The table.
 *  \param [in] row The row number.
 */
TABLE*
attrib_table_get_row_contents (TABLE **table,
                               int row)
{
  return table[row];
}


/*! \brief Set the contents of a table row.
 *
 *  \par Function Description
 *
 *  Sets the contents of a table row.
 *
 *  \param [in] table The table.
 *  \param [in] row The row number.
 *  \param [in] contents The new row contents.
 */
void
attrib_table_set_row_contents (TABLE **table,
                               int row,
                               TABLE *contents)
{
  table[row] = contents;
}


/*------------------------------------------------------------------*/
/*! \brief Create a new table
 *
 * This is the table creator.  It returns a pointer to
 * an initialized TABLE struct.  As calling args, it needs
 * the number of rows and cols to allocate.  The table is a
 * dynamically allocated 2D array of structs.  To access data in
 * a cell in the table, you reference (for example):
 * ((sheet_data->comp_table)[i][j]).attrib_value
 * (Parens used only for clarity.  It works without parens.)
 * \param rows Number of rows required in the new table
 * \param cols Number of columns required in the new table
 * \returns a pointer to an initialized TABLE struct.
 */
TABLE **s_table_new(int rows, int cols)
{
  TABLE **new_table;
  int i, j;

  /* Here I am trying to create a 2 dimensional array of structs */
  new_table = (TABLE **) g_malloc(rows*sizeof(TABLE *));
  for (i = 0; i < rows; i++) {
    attrib_table_set_row_contents (new_table, i, attrib_table_row_new (cols));
    /* Note that I should put some checks in here to verify that
     * malloc worked correctly. */
  }

  /* Now pre-load the table with NULLs */
  for (i = 0; i < rows; i++) {
    for (j = 0; j < cols; j++) {
      (new_table[i][j]).attrib_value = NULL;
      (new_table[i][j]).row_name = NULL;
      (new_table[i][j]).col_name = NULL;
      (new_table[i][j]).row = i;
      (new_table[i][j]).col = j;
      (new_table[i][j]).visibility = VISIBLE;
      (new_table[i][j]).show_name_value = SHOW_VALUE;
    }
  }

  return (new_table);

}


/*! \brief Get cell column number.
 *
 *  \par Function Description
 *
 *  Returns cell column number.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *
 *  \return The column number value.
 */
int
attrib_table_get_column (TABLE **table,
                         int i,
                         int j)
{
  return table[i][j].col;
}


/*! \brief Set cell column number.
 *
 *  \par Function Description
 *
 *  Set cell column number.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *  \param [in] val The new column number value.
 */
void
attrib_table_set_column (TABLE **table,
                         int i,
                         int j,
                         int val)
{
  table[i][j].col = val;
}


/*! \brief Get cell row number.
 *
 *  \par Function Description
 *
 *  Returns cell row number.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *
 *  \return The row number value.
 */
int
attrib_table_get_row (TABLE **table,
                      int i,
                      int j)
{
  return table[i][j].row;
}


/*! \brief Set cell row number.
 *
 *  \par Function Description
 *
 *  Set cell row number.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *  \param [in] val The new row number value.
 */
void
attrib_table_set_row (TABLE **table,
                      int i,
                      int j,
                      int val)
{
  table[i][j].row = val;
}


/*! \brief Get attrib value associated with a cell.
 *
 *  \par Function Description
 *
 *  Returns attrib value associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *
 *  \return The attrib value.
 */
char*
attrib_table_get_attrib_value (TABLE **table,
                               int i,
                               int j)
{
  return table[i][j].attrib_value;
}


/*! \brief Set attrib value associated with a cell.
 *
 *  \par Function Description
 *
 *  Sets attrib value associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *  \param [in] val The new attrib value.
 */
void
attrib_table_set_attrib_value (TABLE **table,
                               int i,
                               int j,
                               char *val)
{
  g_free (table[i][j].attrib_value);

  table[i][j].attrib_value = (val == NULL) ? NULL : g_strdup (val);
}


/*! \brief Get column name associated with a cell.
 *
 *  \par Function Description
 *
 *  Returns column name associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *
 *  \return The column name.
 */
char*
attrib_table_get_column_name (TABLE **table,
                              int i,
                              int j)
{
  return table[i][j].col_name;
}


/*! \brief Set column name associated with a cell.
 *
 *  \par Function Description
 *
 *  Sets column name associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *  \param [in] val The new column name.
 */
void
attrib_table_set_column_name (TABLE **table,
                              int i,
                              int j,
                              char *val)
{
  g_free (table[i][j].col_name);

  table[i][j].col_name = (val == NULL) ? NULL : g_strdup (val);
}


/*! \brief Get row name associated with a cell.
 *
 *  \par Function Description
 *
 *  Returns row name associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The row number of the cell.
 *
 *  \return The row name.
 */
char*
attrib_table_get_row_name (TABLE **table,
                           int i,
                           int j)
{
  return table[i][j].row_name;
}


/*! \brief Set row name associated with a cell.
 *
 *  \par Function Description
 *
 *  Sets row name associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *  \param [in] val The new row name.
 */
void
attrib_table_set_row_name (TABLE **table,
                           int i,
                           int j,
                           char *val)
{
  g_free (table[i][j].row_name);

  table[i][j].row_name = (val == NULL) ? NULL : g_strdup (val);
}


/*! \brief Get attrib visibility associated with a cell.
 *
 *  \par Function Description
 *
 *  Returns attrib visibility associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *
 *  \return The visibility value.
 */
int
attrib_table_get_visibility (TABLE **table,
                             int i,
                             int j)
{
  return table[i][j].visibility;
}


/*! \brief Set attrib visibility associated with a cell.
 *
 *  \par Function Description
 *
 *  Set visiblity of an attrib associated with a table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *  \param [in] val The new visibility value.
 */
void
attrib_table_set_visibility (TABLE **table,
                             int i,
                             int j,
                             int val)
{
  table[i][j].visibility = val;
}


/*! \brief Get \a show_name_value attrib property associated with
 *  a cell.
 *
 *  \par Function Description
 *
 *  Returns \a show_name_value attrib property associated with a
 *  table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *
 *  \return The \a show_name_value value.
 */
int
attrib_table_get_show_name_value (TABLE **table,
                                  int i,
                                  int j)
{
  return table[i][j].show_name_value;
}


/*! \brief Set \a show_name_value attrib property associated with
 *  a cell.
 *
 *  \par Function Description
 *
 *  Sets \a show_name_value attrib property associated with a
 *  table cell.
 *
 *  \param [in] table The table.
 *  \param [in] i The row number of the cell.
 *  \param [in] j The column number of the cell.
 *  \param [in] val The new \a show_name_value value.
 */
void
attrib_table_set_show_name_value (TABLE **table,
                                  int i,
                                  int j,
                                  int val)
{
  table[i][j].show_name_value = val;
}


/*! \brief Make a copy of the \a src array
 *
 * \par Function Description
 * Returns a copy of the 2-dimensional array of the TABLE
 * structures \a src, excluding data in the culumn \a col_skip.
 * It's a helper function to be used in the "delete attrib
 * column" operation.
 * The resulting array has a dimensions of \a rows x \a cols - 1.
 *
 * \param src A source array of the TABLE structures to copy from.
 * \param dst A destination array of the TABLE structures to copy
 *            to.
 * \param col_skip  index of the column to skip (0-based)
 * \param rows      number of rows in \a src
 * \param cols      number of columns in \a src
 *
 * \return          a copy of \a src, minus data in the \a col_skip column
 */
TABLE**
s_table_copy (TABLE **src,
              TABLE **dst,
              int col_skip,
              int rows,
              int cols)
{
  g_return_val_if_fail (src != NULL, NULL);
  g_return_val_if_fail (col_skip < cols, NULL);
  g_return_val_if_fail (dst != NULL, NULL);

  for (int j = 0; j < rows; j++)
  {
    int K = 0;

    for (int k = 0; k < cols - 1; k++)
    {
      if (k == col_skip)
      {
        K ++ ;
      }

      dst[j][k].row             = j;
      dst[j][k].col             = k;
      dst[j][k].visibility      = attrib_table_get_visibility (src, j, K);
      dst[j][k].show_name_value = attrib_table_get_show_name_value (src, j, K);

      dst[j][k].row_name     = g_strdup (attrib_table_get_row_name (src, j, K));
      dst[j][k].col_name     = g_strdup (attrib_table_get_column_name (src, j, K));
      dst[j][k].attrib_value = g_strdup (attrib_table_get_attrib_value (src, j, K));

      K ++ ;

    } /* for: columns */

  } /* for: rows */

  return dst;

} /* s_table_copy() */


/*------------------------------------------------------------------*/
/*! \brief Resize a TABLE
 *
 * This function recreates the table with
 * a new size.  It can only increase
 * the number of cols.  You can't increase the number of rows since
 * gattrib doesn't allow you to input new components.  Decreasing the
 * number of cols is also TBD.
 * \param table Table to resize
 * \param rows Number of rows in the table
 * \param old_cols Number of columns previously in the table
 * \param new_cols Number of columns required in the table
 * \returns a pointer to the resized table
 * \todo The row and column information could be stored in the
 *       TABLE struct.
 */
TABLE **s_table_resize(TABLE **table,
                       int rows, int old_cols, int new_cols)
{
  int i, j;

  /* Here I am trying to resize the 2 dimensional array of structs */
  for (i = 0; i < rows; i++) {
    table[i] = (TABLE *) realloc(table[i], new_cols*sizeof(TABLE) );
    if (table[i] == NULL) exit(-1);  /* die if failed to realloc new memory */
  }

  /* Now pre-load new cols with NULLs */
  for (i = 0; i < rows; i++) {
    for (j = old_cols; j < new_cols; j++) {
      (table[i][j]).attrib_value = NULL;
      (table[i][j]).row_name = NULL;
      (table[i][j]).col_name = NULL;
      (table[i][j]).row = i;
      (table[i][j]).col = j;
      (table[i][j]).visibility = VISIBLE;
      (table[i][j]).show_name_value = SHOW_VALUE;
    }
  }

  return table;
}
