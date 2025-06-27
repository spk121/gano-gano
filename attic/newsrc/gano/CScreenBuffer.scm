#|

A CScreenBuffer is a subclass of the CPresentationBuffer.

It adds the idea of a "screen".  It assumes that there is a rectangle
of character cells (often 25 lines by 80 columns) that indicates which
part of the text is visible on a terminal widget.

It adds primitives that move the virtual screen, and primitives that
render the text in that screen.

|#

