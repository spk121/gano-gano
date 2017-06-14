(define-module (gano ecma48)
  #:export ()
  )

#|

The <Ecma48> class acts as a 'receiving device' of text and coded control
functions.  It takes input from an INPUT PORT, and stores the text
in a CBuffer.  If it receives any control functions for coded character
sets (as described in Standard ECMA-48) it will try to interpret them.

Upon recipt of <eof> from the input port, or of the control function
<esc> + '[' + {optional '0'} + 'i' -- which is the MEDIA COPY command
to the initiate transfer to the primary auxiliary device -- or the ISO
1745 hangup sequence DLE + EOT, the buffered text will be written out
to the MEDIA OUTPUT PORT.

Some control functions (like CPR cursor position report, or DSR device
status report) expect a response from the terminal.  This script will
print the responses to the RESPONSE OUTPUT PORT.

Also, this receiving device does not interpret of the control strings
opened with APC, DCS, OSC, PM, or SOS. These will be written to the
MESSAGE OUTPUT PORT.

This class also acts like a ISO 1745 slave station, and it will
interpret any ISO 1745 messages it receives.  If a response is
requested, it'll be sent to the RESPONSE OUTPUT PORT.  If an ISO 1745
message is received, it will be written to the MESSAGE OUTPUT PORT.

If the input sends an FNK function key message, it is also forwarded
on to the MESSAGE OUTPUT PORT.

It also takes some callbacks. 

There are two device callbacks that take a single boolean
parameter. If the DEVICE 1 CALLBACK is set, it will receive a call
with #t when a DC1 is received and a #f when DC3 is received.  If the
DEVICE 2 CALLBACK is set, it will respond similarly to DC2 and DC4.

There is an alarm callback which takes no parameters.If the
ALARM_CALLBACK is set, it will be called when an ALARM (aka BEL) is
received.

Similarly, there is an INT Interrupt callback.

The script does not fully conform to the standard.  Many features are
unimplemented.  But to be fair, no one device could adhere to all
parts of the standard.

This 'receiving device' is assumes a notional page of 80 columns, 60
lines, and an infinite number of pages.  But it has no real column
limit, so if the text extends beyond the 80th column, it is not
wrapped or dropped.

The Horizontal tab table is initially, 8, 16, ... 80.

The Vertical tab table is initially 6, 12, ... 60.

Input interpretaton must be set to one of the foolowing modes.
- MODE 1: 7-bit controls. 7-bit US-ASCII characters. All codepage
  commands ignored.
- MODE 2: 7-bit controls. 7-bit characters. SO/SI codepage shift is
  enabled.  A G1 table must be given.
- MODE 3: 7-bit and 8-bit controls. ISO-2022 shifts for codepages
  G0 to G3.  Tables for G1, G2, and G3 must be given.
- MODE 4: 7-bit controls. UTF-8 characters.  All codepage commands ignored.

Furthermore, input interpretation has the following flags - COMPOSE:
handle overstruck characters

Character width is ignored completely.  All codepoints stored in the
CBuffer are assumed to have a presentation width of 1, for now.

All "Selected Areas" and "Qualified Areas" functionality is ignored.
This includes "Protected Areas" and "Guarded Areas".  They don't jive
which this type of communcation mode.  The Guarded Area Transfer
Mode (GATM) is unimplemented. This includes SSA, ESA, DAQ, GATM, SPA,
EPA.

Any invalid sequences sent to the INPUT PORT will cause those bytes to
be ignored and an error to be thrown.

|#

#|

----------------
ECMA-16 Behavior

If an ENQ is received by the INPUT PORT, an ACK will be sent to the
RESPONSE OUTPUT PORT.

If a SYN is sent by the INPUT, a SYN will be sent to the RESPONSE OUTPUT
PORT.

If a ECMA-16 message is received by the INPUT PORT, and ACK will be
sent to the RESPONSE OUTPUT PORT.

If a DLE + EOT is sent by the input port, the class will treat it
as if it were an EOF.

All other parts of ECMA-16 will be unimplemented.

----------------
ECMA-35 Behavior

Maybe I'll get this.  Everyone's moved on to UTF-8, though.

For now, ignore all SI/SO and shifts and such

----------------
ECMA-48 Behavior
|#

(define* (make-ecma48-receiver Mode Flags InputPort OutputPort
			       #:keys
			       (MessagePort #f)
			       (ResponseOutPort #f)
			       (DeviceCB1 #f)
			       (DeviceCB2 #f)
			       (AlarmCB #f)
			       (G1Table #f)
			       (G2Table #f)
			       (G3Table #f))

  
