# C++

Used to verify that regex special characters are not misidentified. The filename of C++ contains `+`, which is a regex quantifier.
The script must use grep -F for literal matching, otherwise it will produce false positives.

Referenced by [[Other]], so it is not an orphan.
