# Instructions

Apply this teaching loan policy exactly, in order, to the numeric state.
Select only the first matching rule. Do not introduce other lending requirements.

1. If RequestedPercentIncome is at least 50, select Amount too high.
2. Otherwise, if CreditScore is below 680, select Credit review.
3. Otherwise, if DebtPercentIncome is greater than 40, select Debt too high.
4. Otherwise select Approve.

PowerShell has already calculated RequestedPercentIncome and DebtPercentIncome.
These fields are percentages: 43.75 means 43.75%, not a ratio of 43.75.
Use the supplied percentages directly; do not recalculate them from the amounts.
The amount rule includes equality at 50. The credit rule is strictly below 680.
The debt rule is strictly above 40; equality at 40 is allowed. Do not round
the percentages: 49.99875 is below 50 and 40.00125 is above 40.
The earliest matching rule wins even when later rules also match. Use these
numeric facts rather than general lending judgment.

# Choices

## Amount too high
Deny: RequestedPercentIncome is at least 50. This first rule overrides every later rule.

## Credit review
Refer: RequestedPercentIncome is below 50 and CreditScore is below 680.
This second rule overrides the debt ratio rule.

## Debt too high
Deny: RequestedPercentIncome is below 50, CreditScore is at least 680,
and DebtPercentIncome is greater than 40.

## Approve
Approve: RequestedPercentIncome is below 50, CreditScore is at least 680,
and DebtPercentIncome is at most 40.
