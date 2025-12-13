// https://github.com/raysan5/raylib/discussions/2964

#include "rlgl.h"
#include "glfw3.h"

#define GL_ALPHA_TEST	 0x0BC0
#define GL_GREATER   	 0x0204

// Stencil masks
void beginStencil()
{
	rlDrawRenderBatchActive();
	glEnable(GL_STENCIL_TEST);
}

void beginStencilMask()
{
	glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
	glStencilFunc(GL_ALWAYS, 1, 0xFF);
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
	glEnable(GL_ALPHA_TEST);
	glAlphaFunc(GL_GREATER, 0.5f);
}

void endStencilMask()
{
	rlDrawRenderBatchActive();	
	glDisable(GL_ALPHA_TEST);	
	glStencilFunc(GL_EQUAL, 1, 0xFF);
	glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
	glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
}

void endStencil()
{
	rlDrawRenderBatchActive();
	glDisable(GL_STENCIL_TEST);
}
