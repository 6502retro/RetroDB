# RetroDB 1.1

A forms database for the enhanced Apple IIe, IIc and IIgs, by 6502Retro.

RetroDB keeps any list you can describe with a form, in the spirit of
PFS:File (1982), with the look and feel of Mouse Calc and RetroInv:
80-column MouseText screens, pull-down menus, mouse or keyboard, and
Mouse Calc import and export.

- Design a form of up to 16 fields: Text (1-56), Number, Money, Date, Yes/No,
  No. and Part Of
- Records inside records, to any depth (1.1): a No. field numbers every
  record for good, and a Part Of field says which record this one is in;
  Sort > By Part Of shows the list as an indented tree
- Up to 250 records on a 128K Apple (kept in auxiliary memory)
- Change the form at any time; existing records are converted
- Find, Select Records (contains, =exact, <, >, a..b ranges, /not, blank)
- Sort by any field (again to reverse)
- Report: group by one field, count and total another, with average,
  highest and lowest
- Several databases per folder: New, Open, Save, Save As, Revert to Saved,
  safe saving through a temporary file
- Export the list to a Mouse Calc 1.1 sheet with live SUM totals; import a
  sheet by matching row-1 headings to fields, or make a new database from one

RetroDB contains no code from PFS:File; that program was only a model for
what a forms database does.

## Running it

Boot `release/RETRODB-1.1.po` (a 140K ProDOS disk) on an enhanced IIe with
an 80-column card, a IIc or a IIgs, or in an emulator. ProDOS starts
RETRODB.SYSTEM. Three sample databases (ADDRESSES, COLLECTION, SOFTWARE)
and a sample sheet (COLLECT.MC) are on the disk.

The Owner's Manual explains everything.

## Building

Needs cc65 (ca65/ld65), Python 3 with Pillow, and py65 for the tests.

    ./build.sh                 # build/RETRODB.SYSTEM
    python3 tools/mkrelease.py # release/RETRODB-1.1.po
    for t in test/t*.py; do python3 $t; done
    python3 tools/shots.py     # screenshots for the manual

The tests run RetroDB in a 6502 simulator (tools/sim.py) with ProDOS MLI
calls, auxiliary memory and /RAM emulated.

## Layout

    src/        6502 source (ca65)
    tools/      build, disk image, simulator, splash and sample makers
    test/       simulator tests and Mouse Calc sheet checkers
    prodos/     ProDOS 8 2.4.3 and BASIC.SYSTEM (see NOTICE)
    art/        the 6502 Retro Computing logo used on the title screen
    manual/     screenshots

MIT License; see LICENSE and NOTICE.
