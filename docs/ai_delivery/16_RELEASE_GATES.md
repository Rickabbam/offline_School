# RELEASE GATES

A release candidate is blocked unless all gates are GREEN:

1. build/lint/tests green
2. migrations verified
3. desktop offline critical flows verified
4. sync replay and conflict tests verified
5. finance integrity verified
6. backup/restore drill verified
7. role and scope tests verified
8. installer/upgrade verified
9. pilot truth pass completed
10. docs updated only for code actually shipped

No release on narrative confidence.
Only release on tested evidence.
