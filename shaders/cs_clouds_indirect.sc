/*
 * Draw indirect clouds instances compute shader
 */

#include <bgfx_compute.sh>
#include "./include/config.sh"

BUFFER_RO(count, uint, 0);
BUFFER_WR(indirectBuffer, uvec4, 1);

NUM_THREADS(1, 1, 1)
void main() {
	drawIndexedIndirect(indirectBuffer, 0, 36, count[0], 0, 0, 0);
}
