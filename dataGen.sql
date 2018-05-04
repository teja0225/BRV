DELIMITER ;;

DROP FUNCTION IF EXISTS genAlphaNumString;
DROP FUNCTION IF EXISTS genDate;
DROP FUNCTION IF EXISTS genString;
DROP FUNCTION IF EXISTS genFloat;
DROP FUNCTION IF EXISTS genNumber;
DROP FUNCTION IF EXISTS genTimeStamp;
DROP PROCEDURE IF EXISTS genDATA;

CREATE FUNCTION genFloat(max INT, min INT)
RETURNS FLOAT
DETERMINISTIC
BEGIN
  DECLARE randFNum FLOAT;
  SET randFNum = 0;
  SELECT TRUNCATE((RAND() * (max-min) + min),2)  INTO randFNum;
  RETURN randFNum;
END
;;

CREATE FUNCTION genNumber(max INT, min INT)
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE randNum INT;
  SET randNum = 0;
  SELECT ROUND(RAND() * (max-min) + min)  INTO randNum;
  RETURN randNum;
END
;;

CREATE FUNCTION genString(len INT)
RETURNS varchar(20)
DETERMINISTIC
BEGIN
  DECLARE j INT DEFAULT 0;
  DECLARE randStr varchar(20) default '';
  DECLARE randchar varchar(1) default '';
  DECLARE w_rand_num INT default 0;
  SET j=1;
  WHILE j<=len DO 
    SET w_rand_num = ROUND((RAND() * (90-65))+65);
    SET randchar = char(w_rand_num using utf8);
    IF (ROUND((RAND() * (1)))=0) THEN
      SET randchar = LCASE(randchar);
    END IF;
    SET randStr = CONCAT(randStr,randchar);
    SET j = j + 1;
  END WHILE;
  RETURN randStr;
END
;;

CREATE FUNCTION genDate(max DATE, min DATE)
RETURNS DATE
DETERMINISTIC
BEGIN
  DECLARE randDate DATE default '';
  select from_unixtime(unix_timestamp(min) + floor(rand() * (unix_timestamp(max) - unix_timestamp(min) + 1))) INTO randDate;
  RETURN randDate;
END
;;

CREATE FUNCTION genAlphaNumString(len INT)
RETURNS varchar(10)
DETERMINISTIC
BEGIN
  DECLARE randAlphaNumStr varchar(10) default '';
  SET randAlphaNumStr = lpad(conv(floor(rand()*pow(36,len)),10, 36),len,0);
  RETURN randAlphaNumStr;
END
;;

CREATE FUNCTION genTimeStamp()
RETURNS varchar(30)
DETERMINISTIC
BEGIN
  DECLARE randTimeStamp varchar(30) default '';
  select from_unixtime(unix_timestamp('2017-01-01 01:00:00')+floor(rand()*31536000)) into randTimeStamp;
  RETURN randTimeStamp;
END
;;

CREATE PROCEDURE genDATA(n INT)
BEGIN
DECLARE i INT DEFAULT 0;
DECLARE SSN char(11);
DECLARE Name varchar(10);
DECLARE Descr varchar(20);
DECLARE PhNo varchar(12);
DECLARE DOB DATE;
DECLARE salary INT(11);
DECLARE age INT(11);
DECLARE dept varchar(20);
DECLARE Pd varchar(10);
DECLARE ttimestamp varchar(30);
DECLARE TaxPayed float;

SET i=1;
WHILE i<=n DO 
  SET SSN = concat(genNumber(999,100),"-",genNumber(999,100),"-",genNumber(999,100));
  SET Name = genString(10);
  SET Descr = genString(20);
  SET PhNo = concat(genNumber(999,100),"-",genNumber(999,100),"-",genNumber(9999,1000));
  SET DOB = genDate('1996-12-31','1950-01-01');
  SET salary = genNumber(1100000,100000);
  SET age = genNumber(22,50);
  SET dept = genString(15);
  SET Pd = genAlphaNumString(6);
  SET ttimestamp = genTimeStamp();
  SET TaxPayed = genFloat(100000,50000);
  insert into testData100k (ID,SSN,Name,Descr,PhNo,DOB,salary,age,dept,Password,ttimestamp,TaxPayed) values (i,SSN,Name,Descr,PhNo,DOB,salary,age,dept,Pd,ttimestamp,TaxPayed);
 SET i = i + 1;
END WHILE;
End;
;;

DELIMITER ;

CALL genDATA(100000);
