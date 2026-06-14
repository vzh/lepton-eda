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


#ifdef DEBUG

/*! \brief Debug: print table's contents to STDOUT
 *
 * \param src   2-dimensional array of TABLE structures to print
 * \param rows  number of rows in src
 * \param cols  number of columns in src
 */
void
s_table_print (TABLE** src, int rows, int cols)
{
  printf( "\n\n ++ ++ s_table_print( rows: [%d] cols: [%d] )\n", rows, cols );

  for ( int j = 0; j < rows; j++ )
  {
    printf( "== row: [%d] name: [%s]\n", j, src[j][0].row_name );

    for ( int k = 0; k < cols; k++ )
    {
      printf( "  -- col: [%d] [%s] == [%s]\n", k,
                                               src[j][k].col_name,
                                               src[j][k].attrib_value );

      printf( "     ->row: [%d] ->col: [%d]\n", src[j][k].row,
                                                src[j][k].col );
      printf( "     ->vis: [%d] ->sho: [%d]\n", src[j][k].visibility,
                                                src[j][k].show_name_value );
    }
  }

  printf( "\n" );
}

#endif


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
    new_table[i] = (TABLE *) g_malloc(cols * sizeof(TABLE));
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
 * \param src       an array of the TABLE structures to copy
 * \param col_skip  index of the column to skip (0-based)
 * \param rows      number of rows in \a src
 * \param cols      number of columns in \a src
 *
 * \return          a copy of \a src, minus data in the \a col_skip column
 */
TABLE**
s_table_copy (TABLE** src, int col_skip, int rows, int cols)
{
  g_return_val_if_fail (src != NULL, NULL);
  g_return_val_if_fail (col_skip < cols, NULL);

  TABLE** dst = s_table_new (rows, cols - 1);
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
      dst[j][k].visibility      = src[j][ K ].visibility;
      dst[j][k].show_name_value = src[j][ K ].show_name_value;

      dst[j][k].row_name     = g_strdup( src[j][ K ].row_name );
      dst[j][k].col_name     = g_strdup( src[j][ K ].col_name );
      dst[j][k].attrib_value = g_strdup( src[j][ K ].attrib_value );

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


/*------------------------------------------------------------------*/
/*! \brief Destroy a table
 *
 * This function destroys the old table.
 * Use it after reading in a new
 * page to get rid of the old table before building a new one.
 * \param table Table to destroy
 * \param row_count Number of rows in table
 * \param col_count Number of columns in table
 */
void s_table_destroy(TABLE **table, int row_count, int col_count)
{
  int i, j;

  if (table == NULL)
    return;

  for (i = 0; i < row_count; i++) {
    for (j = 0; j < col_count; j++) {
      g_free( (table[i][j]).attrib_value );
      g_free( (table[i][j]).row_name );
      g_free( (table[i][j]).col_name );
    }
  }

  for (i = 0; i < row_count; i++) {
    g_free( table[i] );
  }

  g_free(table);
  table = NULL;

  return;
}



/*------------------------------------------------------------------*/
/*! \brief Get a string index number
 *
 * This function returns the index number
 * when given a STRING_LIST and a
 * string to match.  It finds the index
 * number by iterating through the master  list.
 * \param local_list
 * \param local_string
 * \returns the index of the string
 */
int s_table_get_index(STRING_LIST *local_list, char *local_string) {
  int count = 0;
  STRING_LIST *list_element;

  g_debug ("s_table_get_index: "
           "Examining %s to see if it is in the list.\n",
           local_string);

  list_element = local_list;
  while (list_element != NULL) {
    if (strcmp(list_element->data, local_string) == 0) {
      return count;
    }
    count++;
    list_element = list_element->next;
  }
  return(-1);  /* return code when string is not in master_list  */
}
