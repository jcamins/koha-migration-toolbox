UPDATE issues SET date_due = CONCAT(SUBSTR(date_due,1,11),'23:59:00');
