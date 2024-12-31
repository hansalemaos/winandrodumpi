# Android Window dumper

Android window dumper ```cmd window dump-visible-window-views``` to pandas DataFrame

```pip install winandrodumpi```

Cython and a C compiler must be installed! The module will be compiled the first time you import it!

```py
import pandas as pd
from cythondfprint import add_printer
from winandrodumpi import parse_window_elements
import numpy as np

add_printer(1)
allparsed = parse_window_elements(
    dump_cmd=[
        "adb",
        "-s",
        "127.0.0.1:5556",
        "shell",
        "cmd window dump-visible-window-views",
    ],
)
alldfs = []
itemindex = 0
for parsed in allparsed:
    try:
        df = pd.DataFrame.from_dict(parsed, orient="index", dtype=object)
        df2 = np.array_split(df, df.loc[~df["id"].isna()].index)
        for item in df2:
            alldfs.append(item.ffill().bfill().assign(aa_itemindex=itemindex))
            itemindex += 1
    except Exception as e:
        print(e)
df = pd.concat(alldfs, ignore_index=True)
print(df)
```