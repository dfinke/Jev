# Grocery list classifier

This example turns a loosely worded grocery list into two bounded classifications: the store section to visit and how to store each item. The item and its context go to Jev together, so “shelf-stable oat milk for coffee” can be classified differently from refrigerated milk without adding a pile of keyword rules.

## Run it

Set `TYPESAFE_API_KEY`, then run the script from this folder:

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
./Classify-GroceryList.ps1
```

The sample CSV contains 12 items. The script makes one live Jev request per item, with both questions included in each request. It does not mock the results or interact with a store.

## What to notice

- `grocery-list.csv` holds the state for each request: the item and the reason it is on the list.
- `section` and `storage` use fixed Choice criteria, so the output stays within categories the PowerShell script can group.
- The script sorts and counts results with ordinary PowerShell after Jev classifies them.
- Choice confidence is preserved in `$results` for follow-up review, even though the compact display focuses on the shopping list.

Try changing an item description or context in the CSV. The categories remain bounded, while Jev can interpret alternate wording.
