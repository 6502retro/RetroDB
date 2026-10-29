# RetroDB Owner's Manual

Oct 28, 2026 · @Jonathan Adar

## RetroDB 1.1

**A forms database for the Apple IIe, IIc and IIgs**

by 6502Retro

&#91;image: The RetroDB title screen\]

### Notice

RetroDB is new software written for this release. Its first version was called MouseDB. It was modeled on the way PFS:File (Software Publishing Corporation, 1982) organizes information into forms, but it contains no code or text from that program, and it is not affiliated with Software Publishing Corporation. Mouse Calc is a product of Version Soft. Apple, Apple IIe, Apple IIc, Apple IIGS and ProDOS are trademarks of Apple Inc.

RetroDB is provided as is, without warranty of any kind. Keep backup copies of your disks and your databases. See the LICENSE file on the source disk for the terms under which RetroDB may be copied and shared.

## Preface: About This Manual

RetroDB keeps any kind of list you can describe with a form: an address book, a record collection, a parts list, a software library. You design the form once, fill in one form for each thing you want to keep track of, and RetroDB finds, sorts, totals and reports on them for you.

If you have used RetroInv or Mouse Calc, RetroDB will feel familiar at once. It uses the same pull-down menus, the same mouse and keyboard commands, the same dialog boxes and the same way of saving your work. It also trades sheets with Mouse Calc in both directions.

### How this manual is organized

- **Chapter 1, Getting Started**, tells you what you need and how to start RetroDB.
- **Chapter 2, A Guided Tour**, shows you the main screen and how to use the menus, the mouse and the keyboard.
- **Chapter 3, Designing a Form**, explains fields and how to set up or change a form.
- **Chapter 4, Working With Records**, covers adding, changing, finding and removing records.
- **Chapter 5, Selecting and Sorting**, shows how to see just the records you want, in the order you want.
- **Chapter 6, Reports**, explains the group-and-total report.
- **Chapter 7, Saving and Keeping More Than One Database**, covers Save, Save As, Open and Revert to Saved.
- **Chapter 8, RetroDB and Mouse Calc**, explains exporting and importing sheets.
- **Chapter 9, Records Inside Records**, shows how to keep track of what is inside what: cards in a computer, a drive on its card, things in a box on a shelf.
- **The appendixes** summarize every command and message, give technical details, and help when something goes wrong.

### Conventions

- **Open-Apple** (the key marked with an outlined apple, shown on screen as a MouseText apple) is held down while you press another key. "Open-Apple-S" means hold Open-Apple and press S. Solid-Apple (Option on the IIgs) works the same way.
- **RETURN**, **ESC**, **TAB** and the arrow keys are shown in capitals.
- Text you type is shown `like this`.
- Choosing a command means pulling down its menu and selecting it, with the mouse or with the keyboard.

> **By the Way:** Notes like this one give helpful extra information.

> **Important!** Notes like this one tell you something you need to know to keep your work safe.

## Chapter 1: Getting Started

RetroDB runs on an enhanced Apple IIe with an 80-column card, an Apple IIc or IIc Plus, or an Apple IIGS, under ProDOS 8.

### What you need

| Item | Needed? | Notes |
| --- | --- | --- |
| Enhanced Apple IIe, IIc or IIGS | Yes | RetroDB uses MouseText and the 80-column screen. An unenhanced IIe shows NEEDS ENHANCED IIE/IIC/IIGS and stops. |
| 128K of memory | Recommended | With 128K, records are kept in the auxiliary 64K and up to 250 fit. With 64K, records share main memory and far fewer fit. |
| A mouse | No | AppleMouse II card on the IIe, the built-in port on the IIc and IIGS. Every command also works from the keyboard. |
| The RetroDB disk | Yes | A 140K ProDOS disk (RETRODB-1.1.po). It can also be copied to a hard disk or a 3.5-inch disk. |
| Mouse Calc | No | Only needed to work with exported sheets. |

### What's on the disk

| File | What it is |
| --- | --- |
| PRODOS | ProDOS 8, version 2.4.3 |
| RETRODB.SYSTEM | The RetroDB program |
| BASIC.SYSTEM | Applesoft BASIC, for your own programs |
| ADDRESSES, COLLECTION, SOFTWARE | Three sample databases to explore. COLLECTION shows records inside other records (Chapter 9). |
| COLLECT.MC | A Mouse Calc sheet exported from COLLECTION, for trying Import |
| RETRODB.LAST | Remembers which database to open when RetroDB starts |

### Make a backup copy first

Before you use RetroDB, copy the disk with the Apple System Utilities, Copy II Plus, or any ProDOS disk copier. Put the original away and work with the copy.

> **Important!** RetroDB saves your databases on the same disk and in the same folder as RETRODB.SYSTEM, so the disk you start from must not be write-protected.

### Starting RetroDB

1. Put the RetroDB disk in the startup drive and turn on the Apple, or press Control-Open-Apple-RESET to restart it.
2. ProDOS starts RETRODB.SYSTEM by itself, and the title screen appears.
3. Press any key or click the mouse button.

From a program selector or ProDOS launcher, such as Bitsy Bye, choose RETRODB.SYSTEM instead. If you copied RetroDB to a hard disk, keep RETRODB.SYSTEM and your databases together in one folder.

&#91;image: Figure 1-1: The title screen\]

After the title screen, RetroDB opens the database you used last. The first time you start it, that is the ADDRESSES sample.

### RetroDB and /RAM

On a 128K Apple, ProDOS sets up the auxiliary 64K as a small disk called /RAM. RetroDB needs that memory for records, so:

- If /RAM is empty, RetroDB borrows it while it runs. When you quit, RetroDB puts /RAM back and formats it again, empty, so it is ready for other programs.
- If /RAM has files on it, RetroDB leaves them alone and keeps records in main memory only. It tells you so when it starts, and fewer records fit.

> **By the Way:** To have room for 250 records, copy anything you want to keep out of /RAM before you start RetroDB.

## Chapter 2: A Guided Tour

Everything in RetroDB starts from one screen: a list of your records, with the menu bar above it and the status line below.

&#91;image: Figure 2-1: The main screen, showing the COLLECTION sample with what is inside what\]

### The parts of the main screen

| Part | Where | What it shows |
| --- | --- | --- |
| Menu bar | Top line | The Apple menu and the File, Record, Sort and View menus, then the name of the open database |
| Column headings | Line 3 | The fields marked "In list" on the form, left to right, as many as fit across 80 columns |
| The list | Middle | 17 records at a time, one per line. The selected record is shown in inverse. |
| Scroll bar | Right edge | Where you are in the list. Click its arrows or the bar itself to move. |
| Status line | Second line from the bottom | How many records are in the list, the total of the first Money field (or the first Number field), and "Modified" when there are unsaved changes |
| Help line | Bottom line | The most-used Open-Apple commands |

When only some records are showing (Chapter 5), the status line says, for example, `4 selected of 14 records`, and the total is for those 4.

### Moving around the list

| To | Keyboard | Mouse |
| --- | --- | --- |
| Select the next or previous record | DOWN ARROW or UP ARROW | Click the record |
| Move a page down or up | RIGHT ARROW or LEFT ARROW | Click the scroll bar below or above its box |
| Open the selected record | RETURN | Click the selected record again |

### Using the menus

With the mouse, click a menu's name in the menu bar, then click the command you want. Click outside the menu to close it without choosing anything.

With the keyboard, press ESC to open the menus. Use LEFT ARROW and RIGHT ARROW to go from menu to menu and UP ARROW and DOWN ARROW to highlight a command, then press RETURN to choose it. Press ESC again to close the menus.

&#91;image: Figure 2-2: The Record menu\]

A command whose name ends in three dots (…) opens a dialog box where you can say more or change your mind. Commands with an Open-Apple key show it at the right of the menu; you can use that key from the main screen without opening the menu at all.

### The menus at a glance

| Menu | Commands |
| --- | --- |
| Apple | About RetroDB |
| File | New Database, Open, Save, Save As, Revert to Saved, Design Form, Import from Mouse Calc, Export to Mouse Calc, Quit |
| Record | New Record, Edit Record, Duplicate Record, Delete Record, Delete Selected, Find, Find Next |
| Sort | By (each field of the form), in the order the fields appear on the form |
| View | Select Records, Show All Records, Report |

### Dialog boxes

Dialog boxes work the same way throughout RetroDB:

- TAB moves from one box or button to the next. UP ARROW and DOWN ARROW also move between boxes.
- RETURN chooses the default button, the one shown in inverse.
- ESC is always the same as Cancel.
- With the mouse, click a box to type in it and click a button to choose it.
- In a text box, CONTROL-X clears what's there, and DELETE or LEFT ARROW erases the character to the left. The quotation mark (") can't be typed, because RetroDB uses it in its files.

## Chapter 3: Designing a Form

A form is the list of blanks you fill in for each record, such as Name, Phone and Birthday in an address book. Each blank is a field. A database has one form, with up to 16 fields.

### Starting a new database

Choose New Database from the File menu. If the open database has unsaved changes, RetroDB first asks whether to save them. The new database is called Untitled, and the Design Form window opens so you can set up its fields.

&#91;image: Figure 3-1: The Design Form window\]

### Setting up a field

Each row of the Design Form window is one field. Type the field's name in the first column, then press TAB to go to the next column.

| Column | What to do |
| --- | --- |
| Field name | Type up to 15 characters (anything but " and \|). Every field needs its own name; capitals don't count, so Name and NAME are the same. |
| Type | Press LEFT ARROW or RIGHT ARROW (or click the arrows) to choose Text, Number, Money, Date or Yes/No. |
| Length | For a Text field, type how many characters it holds, from 1 to 56. New Text fields start at 20. Other types have a fixed length. |
| In list | Yes shows the field as a column in the main list; No keeps it on the form only. Press LEFT ARROW or RIGHT ARROW to change it. |

After the last column, TAB takes you to the next row. A blank row is always waiting at the bottom for a new field.

### The seven types of field

| Type | Holds | You can type | Bytes |
| --- | --- | --- | --- |
| Text | Any characters, up to the field's length | Anything except " | length + 1 |
| Number | Whole numbers from -999,999,999 to 999,999,999 | `1984`, `-5` | 4 |
| Money | Amounts from -$9,999,999.99 to $9,999,999.99 | `12.5`, `$1,250.00` | 4 |
| Date | A date from the year 1000 to 2999, or part of one | `1985-03-21`, `3/21/1985`, `03/1985`, `1985` | 11 |
| Yes/No | Yes, No, or blank | Choose with LEFT ARROW and RIGHT ARROW | 1 |
| No. | A record number from 1 to 999, given by RetroDB | Nothing: RetroDB fills it in | 2 |
| Part Of | The No. of the record this one is inside | A No., or choose with LEFT ARROW and RIGHT ARROW | 2 |

Dates are always shown as YYYY-MM-DD, so they sort correctly. A date can be just a year (`1985`) or a year and month (`1985-03`) when that's all you know.

The line at the bottom of the window shows the record size. All the fields together must fit in 255 bytes.

### Inserting and deleting fields

- To insert a blank field above the highlighted row, press Open-Apple-I or click Insert Field.
- To delete the highlighted field, press Open-Apple-D or click Delete Field.
- The order of the rows is the order of the fields on the form, in the list, and in the Sort menu.

When the form is the way you want it, click OK or press RETURN. Press ESC or click Cancel to leave the form as it was.

### Changing a form later

You can choose Design Form again at any time, even when the database is full of records. You can rename fields, change their types and lengths, add and delete fields, and change which ones are in the list.

If the database already has records, RetroDB warns you before it changes them:

- A field you deleted loses its data in every record.
- A shorter Text field cuts off text that no longer fits.
- A value that doesn't fit a new type is left blank. For example, `Excellent` can't become a Number, but `1985` can.
- Renaming a field keeps its data.

> **Important!** Changing the type or length of a field can't be undone once you click Change in the warning. If you change your mind, choose Revert to Saved from the File menu to go back to the database as it was last saved.

If the new form makes each record longer, fewer records may fit in memory. When the records you have would no longer fit, RetroDB tells you how many would, and doesn't change the form.

## Chapter 4: Working With Records

A record is one filled-in form. A database holds up to 250 records on a 128K Apple.

### Adding a record

Choose New Record from the Record menu, or press Open-Apple-N. The record window opens with every field blank. A No. field shows (new) until you click OK; then RetroDB gives the record its number.

&#91;image: Figure 4-1: The record window, showing that the Disk II Drive is part of the Disk II Controller\]

1. Type the first field. The highlighted name on the left shows which field you are in.
2. Press TAB or DOWN ARROW to go to the next field, UP ARROW to go back.
3. In a Yes/No field, press LEFT ARROW or RIGHT ARROW to choose Yes, No or blank.
4. When you're done, press RETURN or click OK. Press ESC or click Cancel to throw the record away.

The new record goes at the end of the list and is selected, so you can see it. If you've sorted the list, choose the sort again to put it in its place.

RetroDB checks each field when you click OK. If a Number, Money or Date field holds something it can't use, a message says which field and what to type, and you go back to that field. A record with every field blank isn't added.

> **By the Way:** You can leave any field blank. Blank Number and Money fields are left out of totals and averages.

### Changing a record

Select the record and press RETURN, choose Edit Record (Open-Apple-E), or click the selected record. Make your changes and click OK. The record window shows the record's number, such as `Record 3 of 14`.

### Duplicating a record

When a new record is much like one you already have, select that one and choose Duplicate Record (Open-Apple-C). The record window opens with a copy of every field except the No.; the copy gets a number of its own. Change what's different and click OK; the copy is added at the end of the list.

### Deleting records

- **Delete Record** (Open-Apple-D) removes the selected record. RetroDB shows the record's name and asks you to confirm. If other records are inside it, RetroDB says how many (Chapter 9).
- **Delete Selected** removes every record in the list. When you've selected records (Chapter 5) it deletes just those, after asking `Delete the 4 selected records?`; otherwise it asks whether to delete all of them.

> **Important!** Deleted records are gone from memory at once. If you delete something by mistake, choose Revert to Saved before you save, to go back to the copy on disk.

### Finding a record

Choose Find (Open-Apple-F) and type a word or part of one, such as `mouse`. RetroDB looks in every field of the records in the list, starting after the selected record, and selects the first one that contains it. Capitals don't matter.

Choose Find Next (Open-Apple-G) to go on to the next record that matches. The search wraps around to the top of the list. If nothing matches, RetroDB says `No record matches that text.`

### When the database is full

When no more records fit, New Record and Duplicate Record say `The database is full.` You can make room by shortening Text fields with Design Form, or start a second database with New Database (Chapter 7).

## Chapter 5: Selecting and Sorting

Select Records shows only the records you ask for; the Sort menu puts the list in the order you want. Used together, they answer questions like "which cards did I buy after 1984, highest value first?"

### Selecting records

Choose Select Records from the View menu, or press Open-Apple-L. The dialog lists every field of the form with a blank beside it. Type what you're looking for beside one or more fields, then click Select or press RETURN.

&#91;image: Figure 5-1: Selecting the items made in 1984 or later that are worth more than $100\]

The list then shows only the records that match **every** field you filled in. Fields you leave blank don't matter. The status line counts the selected records, and its total is just for them.

&#91;image: Figure 5-2: The four records that match\]

### What you can type

The line at the bottom of the dialog is a reminder of these rules.

| Type this | To find records whose field | Example |
| --- | --- | --- |
| `text` | contains the text (Text fields), starts with it (Date fields), or equals it (Number, Money and Yes/No fields) | `apple` finds Apple IIc and Applesoft |
| `=text` | is exactly the text | `=Apple` finds Apple but not Apple Computer |
| `=` | is blank | `=` beside Bought finds records with no date |
| `<x` `>x` `<=x` `>=x` | is less than, more than, at most, or at least x | `>=1984`, `<$50`, `>M` |
| `<>x` | is anything but x | `<>Good` |
| `a..b` | is from a to b; either end can be left out | `1980..1985`, `..$20` |
| `/x` | does **not** match x, using any of the rules above | `/apple`, `/1980..1985` |
| `/` | is not blank | `/` beside Notes |

Numbers and Money are compared by value, so `>100` finds $125.50 but not $45.00. Text is compared alphabetically, without regard to capitals. Dates are compared by date, and a partial date covers the whole year or month: `1985` finds every date in 1985, and `>=1985-06` finds June 1985 and later.

### Seeing every record again

Choose Show All Records from the View menu, press Open-Apple-A, or click Show All in the Select Records dialog. The selection stays until you show all records again or open another database, so you can add, change and report on just the selected records.

> **By the Way:** Delete Selected (Chapter 4) together with Select Records is a quick way to clear out many records at once, such as every item marked `For Parts`.

### Sorting the list

The Sort menu has a command for each field of the form, such as By Year. Choose one to sort the records by that field, smallest or earliest first, A to Z for text. A check mark shows which field the list is sorted by.

Choose the same field again to reverse the order, largest or latest first; a down arrow beside the check mark shows that it's reversed.

Sorting puts the records themselves in order, so they stay that way when you save the database and the next time you open it. Records with a blank field sort together, before the rest. By Part Of is different: it shows the records as a tree (Chapter 9).

## Chapter 6: Reports

The report sorts the records in the list into groups by one field and counts and totals each group, so you can see at a glance how much of your collection comes from each maker, or how many addresses are in each state.

Choose Report from the View menu, or press Open-Apple-R.

&#91;image: Figure 6-1: The COLLECTION records grouped by Part Of, with the total of Value\]

### Choosing what the report shows

Two choices at the top of the report window decide what it shows. Press TAB (or click) to move between them, and LEFT ARROW or RIGHT ARROW to change the highlighted one. The report is redrawn each time.

| Choice | What you can pick | What it does |
| --- | --- | --- |
| Group by | Any field, or (none) | Makes one line for each different value of the field, in alphabetical order |
| Total of | Any Number or Money field, or (none) | Adds up that field for each group and for the whole report |

When you first open the report, RetroDB picks a likely grouping for you: the Part Of field if the form has one, otherwise the first short Text field after the first field (such as Maker or State), or else a Yes/No field.

### Reading the report

- Each group line shows the value, how many records have it, and their total.
- Records with nothing in the grouping field are counted under `(blank)`.
- The report has room for 9 groups. When there are more, the rest are counted together under `All others`.
- Values are grouped by their first 20 characters, without regard to capitals.
- The **Total** line counts and totals every record in the report.
- Below it, **Average** is the total divided by the number of records that have a value. **Highest** and **Lowest** show the largest and smallest value, with the first field of the record it comes from.

When records are selected (Chapter 5), the window is titled Report on the Selected Records and covers just those. Press RETURN, ESC or click OK to go back to the list.

> **By the Way:** To report on a Date field by year, export the records to Mouse Calc (Chapter 8), or select one year at a time with a criterion such as `1985`.

## Chapter 7: Saving and Keeping More Than One Database

RetroDB works on the database in memory. Your changes are kept only when you save, and "Modified" on the status line reminds you when there is something to save.

### Saving

Choose Save from the File menu, or press Open-Apple-S. The database is written to the disk under its own name, in the same folder as RETRODB.SYSTEM.

An Untitled database has no name yet, so Save asks for one, just as Save As does.

> **By the Way:** RetroDB saves safely. It writes the whole database to a temporary file called RETRODB.SAVING first, and only replaces the old file once the new one is complete. If the disk fills up or something goes wrong, the message says the file on disk was not changed.

### Save As

Save As saves the database under a new name, leaving the old file as it was. Type a name and click Save.

- A name starts with a letter and has up to 15 letters, digits and periods, such as `RECORDS` or `ADDR.1987`. These are the ProDOS rules for file names.
- If a database with that name already exists, RetroDB asks whether to replace it.
- RetroDB won't use the name of a file that isn't a database, or its own files RETRODB.SYSTEM, RETRODB.LAST and RETRODB.SAVING.

After Save As, the new name appears in the menu bar and is the database you're working on.

### Opening another database

Choose Open from the File menu, or press Open-Apple-O. The dialog lists the databases in the RetroDB folder. Highlight one with the arrow keys or the mouse and click Open, or click it a second time.

&#91;image: Figure 7-1: The Open Database dialog\]

The list shows only RetroDB databases, never other files. It has room for 14; when the folder holds more, the dialog says that only the first 14 are listed.

If the database you're leaving has unsaved changes, RetroDB asks first:

&#91;image: Figure 7-2: RetroDB asks before closing a changed database\]

- **Save** saves the changes, then goes on.
- **Don't Save** throws the changes away and goes on.
- **Cancel** stays where you are.

New Database, Open and Quit all ask this question.

### Revert to Saved

Revert to Saved throws away every change since you last saved and reads the database from the disk again. RetroDB asks you to confirm first.

### RETRODB.LAST

Each time you open or save a database, RetroDB writes its name in a small file called RETRODB.LAST. The next time you start RetroDB, it opens that database for you. If the file is missing, RetroDB starts with an empty Untitled database.

### Quitting

Choose Quit from the File menu, or press Open-Apple-Q. After asking about unsaved changes, RetroDB puts /RAM back if it borrowed it and returns to the ProDOS program selector.

> **Important!** Turning off the Apple or pressing RESET without quitting loses your unsaved changes, and leaves /RAM unavailable until the Apple is restarted.

## Chapter 8: RetroDB and Mouse Calc

RetroDB reads and writes Mouse Calc 1.1 sheets directly, so you can move records into a spreadsheet to chart and figure with them, and bring rows from a sheet back in as records. It works the same way as in RetroInv.

### Exporting to Mouse Calc

1. Arrange the list the way you want the sheet: select records (Chapter 5) to export only some of them, and sort it to set the order of the rows.
2. Choose Export to Mouse Calc from the File menu, or press Open-Apple-X.
3. RetroDB suggests a name made from the database's name and `.MC`, such as `COLLECTION.MC`. Change it if you like, then click Export.

&#91;image: Figure 8-1: Exporting the COLLECTION database\]

The sheet is saved in the RetroDB folder, and a message tells you how many records went into it and its full path name. If a Mouse Calc sheet with that name is already there, RetroDB asks before replacing it; it won't replace a file that isn't a sheet.

### What the sheet looks like

| Sheet | Holds |
| --- | --- |
| Row 1 | The field names, one column per field, in the order of the form |
| Rows 2 and on | One record per row, in the order of the list |
| Two rows below the last record | `Total` in the first Text column, and a live `+SUM` formula under each Money column (or each Number column when the form has no Money field) |

- Text, Date and Yes/No fields become text cells. Dates stay as YYYY-MM-DD. No. and Part Of fields become plain numbers.
- Number fields become numbers, and Money fields become numbers shown as dollars and cents.
- Blank fields become empty cells.
- Each column is made as wide as its field, and the columns that fit are set up to show across Mouse Calc's 80-column screen.

Because the totals are real formulas, they update when you change the numbers in Mouse Calc.

### Importing from Mouse Calc

Choose Import from Mouse Calc from the File menu, or press Open-Apple-I. The dialog lists the Mouse Calc sheets in the RetroDB folder. Pick one and click Import.

&#91;image: Figure 8-2: Choosing a sheet to import\]

RetroDB reads row 1 of the sheet as headings and matches each one with a field of the form. The match ignores capitals, spaces and punctuation, so `Item Name` matches a field called ITEMNAME. Columns whose heading matches no field are skipped.

It then asks what to do with the rows:

- **Add** puts them after the records you have.
- **Replace** removes the database's records and puts the sheet's rows in their place.
- **Cancel** leaves the database alone.

Each cell is changed into the type of its field, just as if you had typed it. A value that doesn't fit is left blank. Empty rows, and any row with a `+SUM` formula in it (such as the Total row of an exported sheet), are skipped, so a sheet you exported can come straight back in.

> **Important!** Imported records are not on the disk until you save. If the import isn't what you wanted, choose Revert to Saved to go back.

### Making a database from a sheet

You can turn any Mouse Calc sheet into a new database. Choose New Database, click Cancel in the Design Form window, and then choose Import from Mouse Calc. Because the new database has no form, RetroDB offers to **Create** one from the sheet:

- Each heading in row 1 becomes a field (up to 16), all of them in the list. Columns headed No. and Part Of become fields of those types (Chapter 9).
- A column of plain numbers becomes a Number field; numbers shown as dollars, or with cents, make a Money field.
- A column of dates becomes a Date field, and a column of Yes and No (or Y, N, True, False) a Yes/No field.
- Anything else becomes a Text field, as long as the longest entry plus 10 characters, up to 56.

Afterward, choose Design Form to rename fields, adjust lengths, or take fields out of the list, then save the new database with Save As.

> **By the Way:** If a sheet has more rows than fit in memory, RetroDB imports as many as fit and tells you that some rows did not fit.

## Chapter 9: Records Inside Records

RetroDB 1.1 can keep track of what is inside what: the cards in a computer, the drive on its controller card, the box on a shelf in the closet and everything in the box. Any record can be inside another record, to any depth.

The COLLECTION sample works this way. Open it to follow along.

### The No. and Part Of fields

Two field types make this work. You add them in Design Form like any other field.

| Type | What it holds |
| --- | --- |
| No. | A number from 1 to 999 that RetroDB gives each record. A record keeps its No. for good, however you sort, change or delete other records. You can't type in a No. field. |
| Part Of | The No. of the record this one is inside, or nothing when it isn't inside anything. In the list it shows that record's name. |

A form can have one No. field and one Part Of field. A Part Of field needs a No. field, because it refers to records by their numbers.

When you add a No. field to a database that already has records, RetroDB numbers them 1, 2, 3 and so on, in the order of the list. A new record gets the next number, and Duplicate Record gives the copy a number of its own. Once No. 999 has been used, RetroDB uses the smallest number that is free.

> **By the Way:** A record's name is its first Text field, such as Item or Name. RetroDB uses it wherever it shows a record that another one is part of.

### Putting a record inside another

Open the record and move to its Part Of field.

- Press RIGHT ARROW or LEFT ARROW (or click the arrows) to step through the records it can go in. The name of the one you've chosen appears to the right of the number.
- Or type the No. of the record it belongs in, such as `5`.
- Press CONTROL-X when it isn't inside anything.

When you click OK, RetroDB checks the Part Of field. It won't accept a No. that no record has, and it won't let a record be part of itself or of a record that is inside it, since that would make a loop.

### The list as a tree

Choose By Part Of from the Sort menu to see the database as a tree. Each record is followed by the records inside it, and each level is indented two more spaces in the name column, as in Figure 2-1. A database with a Part Of field opens in this order, and the list stays in it as you add and change records.

### Moving and taking out

- To move a record, change its Part Of. Everything inside it moves along with it.
- To take a record out of its container, clear its Part Of with CONTROL-X.
- When you delete a record that holds others, RetroDB tells you how many. They stay in the database but are no longer part of anything; whatever is inside them stays inside them.

### Finding, selecting and reporting

- **Find** also looks in the names shown in Part Of. After finding `closet` in Hall Closet itself, Find Next goes on to the records inside it.
- In **Select Records**, a word beside Part Of matches the name of the record it is in: `shelf` finds everything on the shelf. A number compares Nos., so `=12` finds the records directly inside No. 12. `=` finds the records that aren't inside anything, and `/` the ones that are.
- Beside No., numbers and ranges work as for a Number field, such as `10..20`.
- The **Report** groups by Part Of when the form has one, so you can see how many things are in each computer or box and what they're worth. Each record counts in the group of the record it is directly inside.

### Part Of and Mouse Calc

- **Export** writes No. and Part Of as plain numbers, so the sheet keeps the links.
- **Import with Replace** keeps the numbers from the sheet.
- **Import with Add** moves the sheet's numbers past the largest No. already in use. The new records keep their links to each other, and any repeated number is replaced with a free one.
- **Create** makes columns headed No. and Part Of into fields of those types, so a database exported from RetroDB comes back with its tree.

> **Important!** MouseDB 1.0, the first version of RetroDB, can't open a database that has a No. or Part Of field. Use RetroDB 1.1 or later for those databases.

## Appendix A: Command Summary

Open-Apple commands work from the main screen. Solid-Apple (Option on the IIGS) can be used in place of Open-Apple.

### Menu commands

| Menu | Command | Keys | What it does |
| --- | --- | --- | --- |
| Apple | About RetroDB | Open-Apple-? | Shows the version and credits |
| File | New Database… |  | Starts an empty Untitled database and opens Design Form |
| File | Open… | Open-Apple-O | Opens another database in the RetroDB folder |
| File | Save | Open-Apple-S | Saves the database (asks for a name if Untitled) |
| File | Save As… |  | Saves under a new name |
| File | Revert to Saved |  | Reloads the database from the disk |
| File | Design Form… |  | Sets up or changes the fields |
| File | Import from Mouse Calc… | Open-Apple-I | Reads rows from a Mouse Calc sheet |
| File | Export to Mouse Calc… | Open-Apple-X | Writes the list as a Mouse Calc sheet |
| File | Quit | Open-Apple-Q | Leaves RetroDB |
| Record | New Record… | Open-Apple-N | Adds a record |
| Record | Edit Record… | Open-Apple-E or RETURN | Changes the selected record |
| Record | Duplicate Record… | Open-Apple-C | Adds a copy of the selected record |
| Record | Delete Record | Open-Apple-D | Removes the selected record |
| Record | Delete Selected… |  | Removes every record in the list |
| Record | Find… | Open-Apple-F | Finds a record containing some text |
| Record | Find Next | Open-Apple-G | Finds the next one |
| Sort | By (field) |  | Sorts by that field; again to reverse. By Part Of shows the tree |
| View | Select Records… | Open-Apple-L | Shows only records that match |
| View | Show All Records | Open-Apple-A | Shows every record again |
| View | Report… | Open-Apple-R | Groups, counts and totals the list |

### Keys on the main screen

| Key | Action |
| --- | --- |
| UP ARROW, DOWN ARROW | Select the previous or next record |
| LEFT ARROW, RIGHT ARROW | Page up or down |
| RETURN | Open the selected record |
| ESC | Open the menus |

### Keys in windows and dialogs

| Key | Action |
| --- | --- |
| TAB, DOWN ARROW | Next box or field |
| UP ARROW | Previous box or field |
| LEFT ARROW, RIGHT ARROW | Change a choice (Type, In list, Yes/No, report choices) |
| DELETE | Erase the character to the left |
| CONTROL-X | Clear the box |
| RETURN | Default button (OK) |
| ESC | Cancel |
| Open-Apple-I, Open-Apple-D | Insert or delete a field (Design Form) |

## Appendix B: Messages

Messages are listed alphabetically by their first words. The messages about No. and Part Of come at the end.

| Message | What it means | What to do |
| --- | --- | --- |
| A database with that name already exists. Replace it? | Save As found a database with the name you typed. | Click Replace to write over it, or Cancel and choose another name. |
| A Mouse Calc sheet with that name already exists. Replace it? | Export found a sheet with that name. | Click Replace, or Cancel and choose another name. |
| A ProDOS name starts with a letter… | The name you typed can't be a ProDOS file name. | Use up to 15 letters, digits and periods, starting with a letter. |
| A Text field holds 1 to 56 characters. | A length in Design Form is out of range. | Type a length from 1 to 56. |
| Could not export the sheet. / Could not open the database. / Could not save the database. / Could not read the sheet. | A disk error stopped the job. The second line names it: the disk is write-protected, the disk is full, disk I/O error, or a ProDOS error number. | Fix the problem and try again. When saving, the file on disk was not changed. |
| Delete this record? | You chose Delete Record. | Click Delete, or Cancel. |
| Delete the 4 selected records? / Delete all 14 records? | You chose Delete Selected. | Click Delete, or Cancel. This can't be undone except by Revert to Saved. |
| Discard your changes and reload the database from disk? | You chose Revert to Saved. | Click Revert, or Cancel. |
| Import the sheet's rows into this database? | The database has a form but no records yet. | Click Import, or Cancel. |
| It isn't a RetroDB database. | The file chosen isn't in RetroDB's format. | Choose another file. |
| Make a new database from this sheet? | You're importing into a database with no form. | Click Create to make fields from the sheet's headings (Chapter 8). |
| No record matches that text. | Find or Find Next found nothing. | Check the spelling, or choose Show All Records if only some records are showing. |
| No records match. | No record fits the Select Records criteria. | Change the criteria, or choose Show All Records. |
| None of the headings in row 1 of that sheet match the fields of this database. | Import found no column to use. | Make row 1 of the sheet hold the field names, or import into a new database. |
| Please add at least one field | The form is empty. | Type a field name in the first row. |
| Please fill in at least one field | The record is blank. | Type something, or press ESC. |
| Please give every field a name | A field row has a type but no name. | Name it, or delete the row with Open-Apple-D. |
| Please type a whole number / an amount / a date in (field) | A field holds something its type can't use. | Correct it, or clear it with CONTROL-X. |
| Row 1 of that sheet has no headings to make fields from. | Create found no text in row 1. | Put a heading over each column in Mouse Calc. |
| Save changes to (name) before closing it? | The database has unsaved changes. | Save, Don't Save, or Cancel (Chapter 7). |
| That name belongs to a file that is not a database / not a Mouse Calc sheet. | The name is taken by another kind of file. | Choose another name. |
| The database is full. | No more records fit in memory. | Shorten fields or start another database. |
| The number in (field) is too large. | It is beyond the field's range. | The largest Number is 999,999,999 and the largest amount $9,999,999.99. |
| The record is longer than 255 bytes. | The fields of the form add up to more than 255 bytes. | Make some Text fields shorter. |
| There are no databases in this folder yet. | Open found no databases. | Choose New Database. |
| There are no Mouse Calc sheets in this folder. | Import found no sheets. | Copy a sheet into the RetroDB folder. |
| This changes all (n) records. | You changed the form of a database with records. | Click Change to go ahead, or Cancel (Chapter 3). |
| This database has more records than fit… | The file holds more records than memory has room for. Only the first ones were loaded. | It opens as Untitled so the file isn't shortened. Free /RAM, or save part of it under a new name. |
| This file doesn't hold the number of records it says… | The file may be damaged. | It opens as Untitled; check the records and save under a new name. |
| Two fields have the same name. | Field names must differ. | Rename one of them. |
| With this form only (n) records fit in memory | The new form makes records too long for the records you have. | Make fields shorter, or delete records first. |
| /RAM has files on it… | RetroDB is keeping records in main memory only. | Quit, copy the files off /RAM, and start RetroDB again for room for 250 records. |
| A form can have only one field of type No. / of type Part Of. | Design Form found two No. fields or two Part Of fields. | Change the type of one of them. |
| A Part Of field holds the No. of another record, so the form needs a field of type No. as well. | The form has Part Of but no No. | Add a No. field, or change Part Of to another type. |
| A record can't be part of itself, or of a record that is inside it. | The Part Of you chose would make a loop. | Choose another record, or press CONTROL-X. |
| It holds 3 records. They stay, no longer part of anything. | Part of the Delete Record message: other records are inside this one. | Click Delete, or Cancel and move them first. |
| No record has the No. typed in Part Of. | The number typed in Part Of belongs to no record. | Choose a record with LEFT ARROW and RIGHT ARROW, or press CONTROL-X. |
| The number in Part Of is too large. The largest is 999. | Record numbers go from 1 to 999. | Type a smaller number. |

## Appendix C: Technical Information

### Limits

| Item | Limit |
| --- | --- |
| Records in a database | 250 with 128K and /RAM free; on a 64K Apple or with files on /RAM, about 2,400 bytes of records (for example, 18 records of 128 bytes) |
| Fields in a form | 16 |
| Field name | 15 characters |
| Text field | 1 to 56 characters |
| Record size | 255 bytes |
| Number field | -999,999,999 to 999,999,999 |
| Money field | -$9,999,999.99 to $9,999,999.99 |
| Dates | Years 1000 to 2999 |
| Databases or sheets in the Open and Import lists | 14 |
| Report groups | 9, plus All others |
| Database and sheet names | 15 characters, ProDOS rules |
| Record numbers (No.) | 1 to 999 |
| Levels of Part Of | Any; up to 10 are shown indented |

### Field sizes

| Type | Bytes in a record |
| --- | --- |
| Text | length + 1 |
| Number, Money | 4 (Money is kept in cents) |
| Date | 11 |
| Yes/No | 1 |
| No., Part Of | 2 |

### Memory

RETRODB.SYSTEM loads at $2000, where its Mouse Calc and file-list code stays. While the title screen is up, RetroDB puts that code aside in auxiliary memory and unpacks the title picture in its place; afterwards the memory that held the packed picture holds the No. tables and records. Records live in the auxiliary 64K from $0800 to $BFFF, reached with the AUXMOVE routine, with leftover room in main memory used too. When /RAM is empty, RetroDB disconnects it as Apple's ProDOS Technical Note #10 describes, and reconnects and formats it on Quit.

### The database file

A database is a ProDOS text file (type TXT, $04), one item per line ending in a carriage return, so it can be read by Applesoft or any text editor:

```
RETRODB1
3
"Name",1,24,1
"Phone",1,12,1
"Birthday",4,10,1
2
"Ada Brightwater"
"555-0101"
"1984-01-24"
"Ben Okafor"
"555-0142"
""
```

- Line 1 is `RETRODB1`, and line 2 the number of fields. Databases saved by MouseDB, as RetroDB was first called, begin with MOUSEDB1; RetroDB opens them too and saves them as RETRODB1.
- Each field is a line of name, type (1 Text, 2 Number, 3 Money, 4 Date, 5 Yes/No, 6 No., 7 Part Of), length (for Text, the length you chose; for other types, the width of the column) and In list (1 or 0).
- Then comes the number of records, and each record as one quoted line per field. Numbers are written plainly (`1985`, `-5`), Money with two decimals (`125.50`), dates as YYYY-MM-DD, and Yes/No as `Yes`, `No` or empty. No. and Part Of are written as numbers, and empty when blank.

### Mouse Calc sheets

Mouse Calc sheets are ProDOS files of type $F8. RetroDB writes Mouse Calc 1.1's 2,179-byte program header, followed by the cells column by column: text cells, number cells in Mouse Calc's decimal format, and SUM formulas with their values already worked out. On import, RetroDB reads text cells, numbers and the cached values of formulas.

### Files RetroDB uses

| File | Purpose |
| --- | --- |
| RETRODB.SYSTEM | The program |
| RETRODB.LAST | The name of the last database used |
| RETRODB.SAVING | A temporary file during Save; it is renamed when the save is complete |
| Your databases | TXT files beginning with RETRODB1 (or MOUSEDB1) |
| Your sheets | $F8 Mouse Calc files |

## Appendix D: Troubleshooting

| Problem | Likely cause | What to do |
| --- | --- | --- |
| The screen says NEEDS ENHANCED IIE/IIC/IIGS. | The Apple IIe has the original ROMs. | Install the Enhancement Kit, or use a IIc or IIGS. |
| The mouse doesn't move the pointer. | No mouse card was found, or the mouse is unplugged. | Use the keyboard; every command works without a mouse. Check the card and cable and restart. |
| Only a few records fit, and RetroDB mentioned /RAM. | Files on /RAM stop RetroDB from using auxiliary memory. | Quit, copy the files elsewhere, and start RetroDB again. |
| Save fails with "The disk is write-protected." | The startup disk is locked. | Use a copy that isn't write-protected. |
| Save fails with "The disk is full." | No room for the database and its temporary copy. | Delete unneeded files, or copy RetroDB to a larger disk. |
| A database isn't in the Open list. | It's in another folder, isn't a RetroDB file, or more than 14 are in the folder. | Copy it next to RETRODB.SYSTEM; move some databases to another folder. |
| A Mouse Calc sheet isn't in the Import list. | It's in another folder, or isn't a $F8 Mouse Calc file. | Save it from Mouse Calc into the RetroDB folder. |
| Import brought in blank columns. | The headings don't match the field names. | Rename the field or the heading so they match. |
| A column I want doesn't show in the list. | It isn't marked In list, or the columns are wider than 80 characters. | In Design Form, mark it In list, shorten Text fields, or take other fields out of the list. |
| RetroDB starts with Untitled instead of my database. | RETRODB.LAST is missing or names a file that isn't there. | Open your database; RetroDB will remember it from then on. |
| Part Of shows a number with a question mark, such as No. 12? | No record has that No., for example after importing part of a sheet. | Open the record and choose the right one in Part Of, or clear it with CONTROL-X. |

## Glossary

- **Criterion:** what you type beside a field in Select Records to say which records you want.
- **Database:** a set of records that share one form, kept in one file.
- **Export:** to write records out to another program's file, here a Mouse Calc sheet.
- **Field:** one blank of a form, such as Name or Value, with a type and a length.
- **Form:** the list of fields that every record in a database has.
- **Import:** to read records in from another program's file.
- **In list:** a field shown as a column of the main list.
- **MouseText:** the set of small pictures, such as the apple and the arrows, that the enhanced Apple II can show in text.
- **ProDOS:** the Apple II disk operating system that RetroDB runs under.
- **/RAM:** the RAM disk ProDOS makes from a 128K Apple's auxiliary memory.
- **Record:** one filled-in form.
- **Selection:** the records that match the Select Records criteria, shown in place of the whole database.
- **Sheet:** a Mouse Calc spreadsheet file.
- **No.:** a record number from 1 to 999 that RetroDB gives each record and never changes.
- **Part Of:** a field that holds the No. of the record this one is inside.
- **Tree order:** the list sorted By Part Of, with each record followed by the records inside it.
