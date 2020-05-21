#ifndef PBI_MIO_H_
#define PBI_MIO_H_

#include "atari.h"
#include <stdio.h>

extern int PBI_MIO_enabled;

void PBI_MIO_Initialise(int *argc, char *argv[]);
UBYTE PBI_MIO_D1GetByte(UWORD addr);
void PBI_MIO_D1PutByte(UWORD addr, UBYTE byte);
UBYTE PBI_MIO_D6GetByte(UWORD addr);
void PBI_MIO_D6PutByte(UWORD addr, UBYTE byte);
int PBI_MIO_ReadConfig(char *string, char *ptr);
void PBI_MIO_WriteConfig(FILE *fp);
void PBI_MIO_StateSave(void);
void PBI_MIO_StateRead(void);

#endif /* PBI_MIO_H_ */