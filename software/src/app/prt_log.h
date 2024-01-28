#pragma once

// Data structure
typedef struct {
     volatile uint16_t head;
     volatile uint16_t tail;
     char buf[1024];
} prt_log_ds_struct;

// Prototypes
void prt_log_init (prt_log_ds_struct *log);
void prt_log_head_inc (prt_log_ds_struct *log);
void prt_log_tail_inc (prt_log_ds_struct *log);
void prt_log_put (prt_log_ds_struct *log, char dat);
char prt_log_get (prt_log_ds_struct *log);
bool prt_log_empty (prt_log_ds_struct *log);
void prt_log_print (prt_log_ds_struct *log);
void prt_log_sprintf (prt_log_ds_struct *log, const char* fmt, ... );
void prt_log_itoa (int num, char *s, int base);
