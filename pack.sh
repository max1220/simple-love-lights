#!/bin/bash
rm game.love
zip -9 -r game.love . -x .git/\* -x example.gif
