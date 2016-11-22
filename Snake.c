#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SNAKE_LEN 6
#define NUM_CYCLES 16

int seg_pos[32];
int levelmap[20*14];

void display()
{
   int x, y;
   for (y = 0; y < 14; y++) {
      char linebuf[21] = { 0 };
      for (x = 0; x < 20; x++) {
         linebuf[x] = levelmap[y*20 + x] ? '#' : '.';
      }
      printf("%s\n", linebuf);
   }
   printf("\n");
}

int main(int argc, char *argv[])
{
   int head = 0;
   int tail = 0;
   int len  = 0;
   int sx   = 10;
   int sy   = 7;
   int counter = 0;

   memset(seg_pos, 0, sizeof(seg_pos));
   memset(levelmap, 0, sizeof(levelmap));

   seg_pos[head] = (sx << 8) | sy;

   while (counter++ < NUM_CYCLES) {
      int x, y;

      // Move
      sx = (sx + 1) % 20;
      
      // Erase tail map cell
      x = seg_pos[tail] >> 8;
      y = seg_pos[tail] & 0xff;
      levelmap[y*20 + x] = 0;

      // Adjust size
      head = (head + 1) & 31;
      if (len < SNAKE_LEN) {
         len++;
      } else {
         tail = (tail + 1) & 31;
      }

      // Mark head map cell
      seg_pos[head] = (sx << 8) | sy;
      levelmap[sy*20 + sx] = 1;

      display();
   }
}
