How to add a new language:

You have to know your language code. Currently, the gettext unit simply takes
the first and second character of the environment variable $LANG.
Examples for this 2-char language codes are
  de  for German
  en  for English
  fr  for Frensh

you can check the currently selected language with the command
  echo $LANG

change this value using
(in bash)
  export LANG=<langcode>
(in csh)
  setenv LANG <langcode>

Then, make a copy of the file "restest.po", call the copy
  restest.<langcode>.po
(Insert your language code for <langcode>)

After this you can edit the created .po file using your favorite editor.
For each string, there is an "msgid" and an "msgstr" entry. msgid is the
original string, don't change its value. Just add the translated string to
the "msgstr" line. Please translate the strings carefully, especially some
special characters like "%" inserts or quotation marks have to be at exactly
the same semantic position as in the original string.

When you are finished with your translation, create the .mo file with:

msgfmt -o restest.<langcode>.mo restest.<langcode>.po

The restest example program loads this .mo file. msgfmt is part of the GNU
gettext tools. The former Makefile has been retired.

If you add a new language, please send the .po file to the Free Pascal
developers.

Michael. <michael@freepascal.org>
