;; Copyright 2017 Michael L. Gran

;; This file is part of Gano.

;; Gano is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; Guile-Ncurses is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Lesser General Public License for more details.

;; You should have received a copy of the GNU Lesser General Public
;; License along with Guile-Ncurses.  If not, see
;; <http://www.gnu.org/licenses/>.

(use-modules (test automake-test-lib)
             (gano CBuffer))

;; If I try to backspace from column 0, I should still be at column 0.
(automake-test
 (let* ((CB (make-empty-cbuffer)))
   (write-character CB #\A 'data)
   (write-character CB #\B 'data)
   (backspace CB)
   (= 1 (get-pd-cur CB))))
