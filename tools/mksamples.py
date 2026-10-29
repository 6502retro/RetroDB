"""Write the sample databases shipped on the RetroDB disk (RETRODB1 text files)."""
import sys, os
KIND = {'Text': 1, 'Number': 2, 'Money': 3, 'Date': 4, 'Yes/No': 5, 'No.': 6, 'Part Of': 7}
def db(path, fields, records):
    out = ['RETRODB1', str(len(fields))]
    for (n, k, l, s) in fields:
        out.append('"%s",%d,%d,%d' % (n, KIND[k], l if k == 'Text' else {'Number': 10, 'Money': 12, 'Date': 10, 'Yes/No': 3, 'No.': 4, 'Part Of': 20}[k], s))
    out.append(str(len(records)))
    for r in records:
        assert len(r) == len(fields), r
        for (f, v) in zip(fields, r):
            assert '"' not in v and (f[1] != 'Text' or len(v) <= f[2]), (f, v)
            out.append('"%s"' % v)
    open(path, 'wb').write(('\r'.join(out) + '\r').encode('ascii'))

out = sys.argv[1]
os.makedirs(out, exist_ok=True)

# an address book (the people are made up)
db(out + '/ADDRESSES',
   [('Name', 'Text', 24, 1), ('Company', 'Text', 18, 0), ('Phone', 'Text', 12, 1),
    ('City', 'Text', 13, 1), ('State', 'Text', 2, 1), ('Birthday', 'Date', 0, 1),
    ('Email', 'Text', 30, 0), ('Card', 'Yes/No', 0, 1), ('Notes', 'Text', 40, 0)],
   [['Ada Brightwater', 'Clockwork Co.', '555-0101', 'Portland', 'OR', '1984-01-24', 'ada@example.com', 'Yes', 'Met at KansasFest'],
    ['Ben Okafor', '', '555-0142', 'Austin', 'TX', '1979-06-11', 'ben@example.com', 'Yes', ''],
    ['Carla Mendes', 'Pixel Works', '555-0177', 'Tucson', 'AZ', '1991-03-02', '', 'No', 'Collects IIgs cards'],
    ['Dmitri Volkov', '', '555-0119', 'Buffalo', 'NY', '', 'dmitri@example.com', 'Yes', ''],
    ['Elena Ruiz', 'Ruiz Repair', '555-0163', 'Denver', 'CO', '1988-11-30', 'elena@example.com', 'Yes', 'Recaps power supplies'],
    ['Frank Tilden', '', '555-0128', 'Omaha', 'NE', '1965-08-15', '', 'No', ''],
    ['Grace Liu', 'Byte Shop', '555-0150', 'San Jose', 'CA', '1977-04-16', 'grace@example.com', 'Yes', 'Sells disk drives'],
    ['Hank Morrow', '', '555-0136', 'Boise', 'ID', '', '', 'No', 'Has a spare IIc'],
    ['Ines Duarte', '', '555-0185', 'Miami', 'FL', '1995-12-03', 'ines@example.com', 'Yes', ''],
    ['Jonas Berg', 'Northern Retro', '555-0111', 'Duluth', 'MN', '1982-07-09', 'jonas@example.com', 'Yes', 'Swap meet in June'],
    ['Kim Palmer', '', '555-0190', 'Richmond', 'VA', '1970-02-28', '', 'No', ''],
    ['Leo Santos', '', '555-0158', 'Tampa', 'FL', '1986-09-21', 'leo@example.com', 'Yes', 'Mouse Calc fan']])

# a retro computer collection, like RetroInv's: No. and Part Of show
# what is inside what (cards in a computer, a drive on its card, things in
# a box in the closet)
C = [('No.', 'No.', 0, 1), ('Item', 'Text', 28, 1), ('Part Of', 'Part Of', 0, 1),
     ('Maker', 'Text', 12, 0), ('Year', 'Number', 0, 0), ('Type', 'Text', 10, 1),
     ('Condition', 'Text', 9, 0), ('Value', 'Money', 0, 1), ('Bought', 'Date', 0, 0),
     ('Works', 'Yes/No', 0, 0), ('Notes', 'Text', 40, 0)]
db(out + '/COLLECTION', C,
   [['1', 'Apple IIe Enhanced', '', 'Apple', '1985', 'Computer', 'Excellent', '450.00', '2019-05-11', 'Yes', 'Platinum keyboard, 128K'],
    ['2', 'Extended 80-Column Card', '1', 'Apple', '1983', 'Card', 'Excellent', '35.00', '2019-05-11', 'Yes', 'Aux slot, 64K'],
    ['3', 'Super Serial Card', '1', 'Apple', '1981', 'Card', 'Good', '40.00', '', 'Yes', 'Slot 2'],
    ['4', 'AppleMouse II Card', '1', 'Apple', '1984', 'Card', 'Good', '45.00', '2020-02-01', 'Yes', 'Slot 4, mouse in drawer'],
    ['5', 'Disk II Controller', '1', 'Apple', '1978', 'Card', 'Good', '60.00', '', 'Yes', 'Slot 6'],
    ['6', 'Disk II Drive', '5', 'Apple', '1978', 'Peripheral', 'Good', '125.50', '2018-10-20', 'Yes', 'Drive 1, cleaned heads'],
    ['7', 'Apple IIGS ROM 3', '', 'Apple', '1989', 'Computer', 'Excellent', '600.00', '2021-07-04', 'Yes', '4 MB'],
    ['8', 'AppleColor RGB Monitor', '7', 'Apple', '1986', 'Peripheral', 'Good', '150.00', '2021-07-04', 'Yes', ''],
    ['9', 'Apple 3.5 Drive', '7', 'Apple', '1986', 'Peripheral', 'Fair', '80.00', '', 'No', 'Slow eject'],
    ['10', 'Apple IIc', '', 'Apple', '1984', 'Computer', 'Good', '275.00', '2017-03-18', 'Yes', 'With carrying case'],
    ['11', 'Hall Closet', '', '', '', 'Place', '', '', '', '', 'Top shelf'],
    ['12', 'Storage Box A', '11', '', '', 'Box', '', '', '', '', 'Plastic tub'],
    ['13', 'Oregon Trail', '12', 'MECC', '1985', 'Software', 'For Parts', '20.00', '', 'No', 'Disk will not boot'],
    ['14', 'Kraft Joystick', '12', 'Kraft', '1982', 'Accessory', 'Poor', '5.00', '', 'Yes', 'Sticky button'],
    ['15', 'AppleWorks 3.0 Manual', '12', 'Claris', '1989', 'Documents', 'Excellent', '15.00', '2022-01-15', '', ''],
    ['16', 'ImageWriter II', '11', 'Apple', '1985', 'Peripheral', 'Good', '90.00', '2016-09-09', 'Yes', 'New ribbon']])

# a software library
db(out + '/SOFTWARE',
   [('Title', 'Text', 24, 1), ('Publisher', 'Text', 16, 1), ('Year', 'Number', 0, 1),
    ('Genre', 'Text', 12, 1), ('Format', 'Text', 5, 1), ('Disks', 'Number', 0, 0),
    ('Paid', 'Money', 0, 1), ('Boxed', 'Yes/No', 0, 1), ('Manual', 'Yes/No', 0, 0)],
   [['Karateka', 'Broderbund', '1984', 'Action', '5.25', '1', '25.00', 'Yes', 'Yes'],
    ['Lode Runner', 'Broderbund', '1983', 'Puzzle', '5.25', '1', '30.00', 'No', 'Yes'],
    ['Choplifter', 'Broderbund', '1982', 'Action', '5.25', '1', '18.00', 'Yes', 'No'],
    ['Zork I', 'Infocom', '1980', 'Adventure', '5.25', '1', '45.50', 'Yes', 'Yes'],
    ['Ultima IV', 'Origin', '1985', 'Role-playing', '5.25', '4', '60.00', 'Yes', 'Yes'],
    ['The Oregon Trail', 'MECC', '1985', 'Education', '5.25', '2', '20.00', 'No', 'No'],
    ['AppleWorks 3.0', 'Claris', '1989', 'Office', '3.5', '2', '35.00', 'Yes', 'Yes'],
    ['Print Shop', 'Broderbund', '1984', 'Graphics', '5.25', '2', '22.00', 'No', 'Yes'],
    ['Mouse Calc', 'Version Soft', '1984', 'Office', '5.25', '2', '40.00', 'Yes', 'Yes'],
    ['Carmen Sandiego', 'Broderbund', '1985', 'Education', '5.25', '2', '15.00', 'No', 'No'],
    ['Wizardry', 'Sir-Tech', '1981', 'Role-playing', '5.25', '2', '55.00', 'Yes', 'Yes'],
    ['Prince of Persia', 'Broderbund', '1989', 'Action', '5.25', '2', '28.00', 'Yes', 'Yes'],
    ['Hard Hat Mack', 'Electronic Arts', '1983', 'Action', '5.25', '1', '12.00', 'No', 'No'],
    ['Copy II Plus', 'Central Point', '1987', 'Utility', '3.5', '1', '25.00', 'No', 'Yes'],
    ['ProDOS 8 2.4.3', 'John Brooks', '2023', 'Utility', '5.25', '1', '0.00', 'No', 'No']])
print('wrote ADDRESSES, COLLECTION, SOFTWARE')
