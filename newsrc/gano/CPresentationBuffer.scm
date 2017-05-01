#|

A CPresentationBuffer is a subclass of CBuffer.  It is a model for
storing and editing lines of text.

The CPresentationBuffer adds logic to handle the difference between
how strings are stored, in logical order with one codepoint per "unit",
versus how they are presented, in visual order with codepoints
that can can have varying screen widths.

|#
