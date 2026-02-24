
-- Hospital Patient Management System - Database Implementation Script

CREATE DATABASE IF NOT EXISTS hospital_patient_management_system;
USE hospital_patient_management_system;

-- 1. Departments Table
CREATE TABLE Departments (
    department_id INT PRIMARY KEY AUTO_INCREMENT,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    dept_phone VARCHAR(15),
    email VARCHAR(100)
);

-- 2. Patients Table
CREATE TABLE Patients (
    patient_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_name VARCHAR(100) NOT NULL,
    age INT CHECK (age > 0),
    gender ENUM('Male', 'Female', 'Other') NOT NULL,
    blood_group VARCHAR(5),
    address VARCHAR(255),
    phone_number VARCHAR(15) UNIQUE,
    email VARCHAR(100) UNIQUE,
    additional_info JSON
);

-- 3. Doctors Table
CREATE TABLE Doctors (
    doctor_id INT PRIMARY KEY AUTO_INCREMENT,
    doctor_name VARCHAR(100) NOT NULL,
    specialization VARCHAR(100),
    phone VARCHAR(15),
    email VARCHAR(100),
    department_id INT,
    FOREIGN KEY (department_id) REFERENCES Departments(department_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- 4. Appointments Table
CREATE TABLE Appointments (
    appointment_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT NOT NULL,
    doctor_id INT,
    appointment_date DATETIME NOT NULL,
    appointment_status ENUM('Scheduled', 'Completed', 'Cancelled') DEFAULT 'Scheduled',
    reason VARCHAR(255),
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (doctor_id) REFERENCES Doctors(doctor_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- 5. Medical_Tests Table
CREATE TABLE Medical_Tests (
    test_id INT PRIMARY KEY AUTO_INCREMENT,
    test_name VARCHAR(100) NOT NULL,
    appointment_id INT,
    test_fees DECIMAL(8,2) NOT NULL,
    test_date DATE NOT NULL,
    result VARCHAR(100),
    FOREIGN KEY (appointment_id) REFERENCES Appointments(appointment_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- 6. Billing Table
CREATE TABLE Billing (
    billing_id INT PRIMARY KEY AUTO_INCREMENT,
    patient_id INT NOT NULL,
    test_id INT,
    amount DECIMAL(10,2) NOT NULL,
    payment_status ENUM('Paid', 'Unpaid', 'Pending') DEFAULT 'Pending',
    payment_date DATETIME,
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (test_id) REFERENCES Medical_Tests(test_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- 7. Room_Allocation Table
CREATE TABLE Room_Allocation (
    room_id INT PRIMARY KEY AUTO_INCREMENT,
    room_type ENUM('Private', 'Semi-private', 'General') NOT NULL,
    patient_id INT NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE,
    room_status VARCHAR(20) DEFAULT 'Occupied',
    FOREIGN KEY (patient_id) REFERENCES Patients(patient_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 8. Staff_Allocation Table
CREATE TABLE Staff_Allocation (
    staff_id INT,
    staff_name VARCHAR(100) NOT NULL,
    room_id INT NOT NULL,
    assigned_from DATE NOT NULL,
    assigned_to DATE,
    FOREIGN KEY (room_id) REFERENCES Room_Allocation(room_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);
ALTER TABLE Staff_Allocation DROP PRIMARY KEY;

-- 9. Trigger: Auto-update Room to Occupied on Insert
DELIMITER //
CREATE TRIGGER trg_room_status_on_insert
AFTER INSERT ON Room_Allocation
FOR EACH ROW
BEGIN
    UPDATE Room_Allocation
    SET room_status = 'Occupied'
    WHERE room_id = NEW.room_id;
END;
//
DELIMITER ;

-- 10. Trigger: Auto-update Room to Available on Checkout
DELIMITER //
CREATE TRIGGER trg_room_status_on_checkout
AFTER UPDATE ON Room_Allocation
FOR EACH ROW
BEGIN
    IF NEW.check_out_date IS NOT NULL THEN
        UPDATE Room_Allocation
        SET room_status = 'Available'
        WHERE room_id = NEW.room_id;
    END IF;
END;
//
DELIMITER ;

-- 11. Stored Procedure: Create Appointment
DELIMITER //
CREATE PROCEDURE create_appointment (
    IN p_patient_id INT,
    IN p_doctor_id INT,
    IN p_date DATETIME,
    IN p_reason VARCHAR(255)
)
BEGIN
    IF p_date < NOW() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Appointment date cannot be in the past';
    END IF;
    INSERT INTO Appointments (patient_id, doctor_id, appointment_date, reason)
    VALUES (p_patient_id, p_doctor_id, p_date, p_reason);
END;
//
DELIMITER ;

-- 12. Stored Procedure: Generate Billing by Patient
DELIMITER //
CREATE PROCEDURE generate_billing_by_patients (
    IN p_patient_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK TO SAVEPOINT billing_savepoint;
    END;

    START TRANSACTION;
    SAVEPOINT billing_savepoint;

    INSERT INTO Billing (patient_id, test_id, amount, payment_status, payment_date)
    SELECT 
        p_patient_id,
        mt.test_id,
        mt.test_fees,
        'Pending',
        NULL
    FROM Appointments a
    JOIN Medical_Tests mt ON a.appointment_id = mt.appointment_id
    WHERE a.patient_id = p_patient_id
      AND mt.test_id NOT IN (
          SELECT test_id FROM Billing WHERE patient_id = p_patient_id
      );

    COMMIT;
END;
//
DELIMITER ;
