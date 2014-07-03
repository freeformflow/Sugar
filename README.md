Sugar
=====
Sugar is a parser-combinator library that adds kick-ass functionality to CoffeeScript.
CoffeeScript is already easier to write and maintain than hand-written JavaScript.
Sugar takes it to the next level and makes it execute faster.  So, what's not to like?
Take your CoffeeScript with a spoonful of Sugar.

The goal is to retain CoffeeScript's grace while allowing it access to another
translation target.  Sugar targets Low-Level JavaScript (LLJS), an experimental
JavaScript variant that self-describes as the "bastard child of JavaScript and C".

LLJS produces valid JavaScript, but nothing that you would want to write by
hand.  LLJS produces asm.js style code that runs fast.  With static type coercion
and better memory management, the JavaScript that LLJS produces doesn't need
time-consuming garbage collection, and it can be better optimized by Just-In-Time
compilers that are standard in modern browsers.  You can even target experiemntal
Ahead-Of-Time compilers if you fully conform to the asm.js style.

- Copyright 2014 by PandaStrike  http://www.pandastrike.com
- This project is released under the MIT License
- LLJS Project Homepage:  http://mbebenita.github.io/LLJS/

To Do List:
(0) Port of CoffeeScript Translator
(1) Statically typed variables
(2) Pointers
(3) Structs
(4) Unions
(5) Typed functions
(6) Malloc & Free


