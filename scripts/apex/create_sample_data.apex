// Safe Sample Data Generation Script for Recruitment AI
// Fictional demonstration data only

System.debug('--- Cleaning existing sample data ---');
delete [SELECT Id FROM Interview__c];
delete [SELECT Id FROM Job_Application__c];
delete [SELECT Id FROM Candidate__c];
delete [SELECT Id FROM Job_Requisition__c];

Id currentUserId = UserInfo.getUserId();

System.debug('--- Creating Job Requisitions ---');
List<Job_Requisition__c> requisitions = new List<Job_Requisition__c>{
    new Job_Requisition__c(
        Job_Title__c = 'AI/ML Engineer',
        Job_Code__c = 'REQ-AIML-001',
        Department__c = 'Artificial Intelligence',
        Location__c = 'San Francisco, CA',
        Employment_Type__c = 'Full-Time',
        Job_Description__c = 'Design and implement state-of-the-art machine learning models, LLM workflows, and generative AI pipelines.',
        Required_Skills__c = 'Python, PyTorch, TensorFlow, LLMs, Prompt Engineering, Agentforce, LangChain, REST APIs',
        Experience_Required__c = 4.0,
        Minimum_Qualification__c = 'Bachelor or Master of Science in Computer Science / AI',
        Number_of_Positions__c = 3,
        Hiring_Manager__c = currentUserId,
        Recruiter__c = currentUserId,
        Opening_Date__c = Date.today().addDays(-20),
        Status__c = 'Open'
    ),
    new Job_Requisition__c(
        Job_Title__c = 'Python Developer',
        Job_Code__c = 'REQ-PY-002',
        Department__c = 'Software Development',
        Location__c = 'Austin, TX',
        Employment_Type__c = 'Full-Time',
        Job_Description__c = 'Develop high-performance backend microservices, async task processors, and REST APIs using Python and FastAPI.',
        Required_Skills__c = 'Python, Django, FastAPI, PostgreSQL, Docker, Redis, Celery, CI/CD',
        Experience_Required__c = 3.0,
        Minimum_Qualification__c = 'Bachelor of Science in Computer Science or equivalent',
        Number_of_Positions__c = 2,
        Hiring_Manager__c = currentUserId,
        Recruiter__c = currentUserId,
        Opening_Date__c = Date.today().addDays(-15),
        Status__c = 'Open'
    ),
    new Job_Requisition__c(
        Job_Title__c = 'Java Developer',
        Job_Code__c = 'REQ-JAVA-003',
        Department__c = 'Software Development',
        Location__c = 'Seattle, WA',
        Employment_Type__c = 'Full-Time',
        Job_Description__c = 'Build mission-critical enterprise services, microservice architectures, and robust transaction processing systems using Spring Boot.',
        Required_Skills__c = 'Java 17/21, Spring Boot, Microservices, Kafka, Hibernate, AWS, Kubernetes',
        Experience_Required__c = 5.0,
        Minimum_Qualification__c = 'Bachelor of Engineering in Computer Science',
        Number_of_Positions__c = 4,
        Hiring_Manager__c = currentUserId,
        Recruiter__c = currentUserId,
        Opening_Date__c = Date.today().addDays(-10),
        Status__c = 'Open'
    ),
    new Job_Requisition__c(
        Job_Title__c = 'Data Analyst',
        Job_Code__c = 'REQ-DATA-004',
        Department__c = 'Data Science',
        Location__c = 'New York, NY',
        Employment_Type__c = 'Full-Time',
        Job_Description__c = 'Transform complex recruitment and operational metrics into actionable executive dashboards and data models.',
        Required_Skills__c = 'SQL, Tableau, Power BI, Python, Excel, Statistical Modeling, BigQuery',
        Experience_Required__c = 2.5,
        Minimum_Qualification__c = 'Bachelor in Statistics, Mathematics, or Data Analytics',
        Number_of_Positions__c = 2,
        Hiring_Manager__c = currentUserId,
        Recruiter__c = currentUserId,
        Opening_Date__c = Date.today().addDays(-25),
        Status__c = 'Open'
    ),
    new Job_Requisition__c(
        Job_Title__c = 'Software Engineer',
        Job_Code__c = 'REQ-SWE-005',
        Department__c = 'Software Development',
        Location__c = 'Remote - US',
        Employment_Type__c = 'Full-Time',
        Job_Description__c = 'Full-stack engineering role delivering cloud-native web applications and integration microservices.',
        Required_Skills__c = 'JavaScript, TypeScript, React, Node.js, REST APIs, Git, Cloud Infrastructure',
        Experience_Required__c = 3.0,
        Minimum_Qualification__c = 'Bachelor of Science in Information Technology / CS',
        Number_of_Positions__c = 5,
        Hiring_Manager__c = currentUserId,
        Recruiter__c = currentUserId,
        Opening_Date__c = Date.today().addDays(-5),
        Status__c = 'Open'
    )
};
insert requisitions;
System.debug('Inserted ' + requisitions.size() + ' Job Requisitions.');

System.debug('--- Creating Fictional Candidates ---');
List<Candidate__c> candidates = new List<Candidate__c>{
    new Candidate__c(
        Candidate_Name__c = 'Alex Morgan',
        Email__c = 'alex.morgan@example.com',
        Phone__c = '555-010-1001',
        Location__c = 'San Francisco, CA',
        Highest_Qualification__c = 'MS in Artificial Intelligence',
        University__c = 'Stanford University',
        Graduation_Year__c = 2021,
        Years_of_Experience__c = 4.5,
        Skills__c = 'PyTorch, Python, NLP, LLMs, Transformer architectures, Agentforce',
        Resume_Link__c = 'https://example.com/resumes/alex-morgan',
        Candidate_Status__c = 'New'
    ),
    new Candidate__c(
        Candidate_Name__c = 'Brenda Vance',
        Email__c = 'brenda.vance@example.com',
        Phone__c = '555-010-1002',
        Location__c = 'Austin, TX',
        Highest_Qualification__c = 'BS in Computer Science',
        University__c = 'University of Texas at Austin',
        Graduation_Year__c = 2020,
        Years_of_Experience__c = 5.0,
        Skills__c = 'Python, FastAPI, Docker, PostgreSQL, Redis, Kubernetes, Microservices',
        Resume_Link__c = 'https://example.com/resumes/brenda-vance',
        Candidate_Status__c = 'New'
    ),
    new Candidate__c(
        Candidate_Name__c = 'Carlos Mendez',
        Email__c = 'carlos.mendez@example.com',
        Phone__c = '555-010-1003',
        Location__c = 'Seattle, WA',
        Highest_Qualification__c = 'BS in Software Engineering',
        University__c = 'University of Washington',
        Graduation_Year__c = 2018,
        Years_of_Experience__c = 6.5,
        Skills__c = 'Java, Spring Boot, Microservices, Kafka, AWS, Maven, Hibernate',
        Resume_Link__c = 'https://example.com/resumes/carlos-mendez',
        Candidate_Status__c = 'New'
    ),
    new Candidate__c(
        Candidate_Name__c = 'Diana Chen',
        Email__c = 'diana.chen@example.com',
        Phone__c = '555-010-1004',
        Location__c = 'New York, NY',
        Highest_Qualification__c = 'MS in Data Analytics',
        University__c = 'Columbia University',
        Graduation_Year__c = 2022,
        Years_of_Experience__c = 3.0,
        Skills__c = 'SQL, Tableau, Python, Pandas, Statistical Analysis, Power BI, BigQuery',
        Resume_Link__c = 'https://example.com/resumes/diana-chen',
        Candidate_Status__c = 'New'
    ),
    new Candidate__c(
        Candidate_Name__c = 'Ethan Walker',
        Email__c = 'ethan.walker@example.com',
        Phone__c = '555-010-1005',
        Location__c = 'Chicago, IL',
        Highest_Qualification__c = 'BS in Computer Engineering',
        University__c = 'University of Illinois Urbana-Champaign',
        Graduation_Year__c = 2021,
        Years_of_Experience__c = 3.5,
        Skills__c = 'React, Node.js, TypeScript, Next.js, GraphQL, MongoDB, REST',
        Resume_Link__c = 'https://example.com/resumes/ethan-walker',
        Candidate_Status__c = 'New'
    ),
    new Candidate__c(
        Candidate_Name__c = 'Fiona Gallagher',
        Email__c = 'fiona.gallagher@example.com',
        Phone__c = '555-010-1006',
        Location__c = 'Boston, MA',
        Highest_Qualification__c = 'MS in Computer Science',
        University__c = 'MIT',
        Graduation_Year__c = 2020,
        Years_of_Experience__c = 4.5,
        Skills__c = 'Deep Learning, Computer Vision, Python, PyTorch, C++, TensorRT',
        Resume_Link__c = 'https://example.com/resumes/fiona-gallagher',
        Candidate_Status__c = 'New'
    ),
    new Candidate__c(
        Candidate_Name__c = 'George Brooks',
        Email__c = 'george.brooks@example.com',
        Phone__c = '555-010-1007',
        Location__c = 'Denver, CO',
        Highest_Qualification__c = 'BS in Information Systems',
        University__c = 'University of Colorado Boulder',
        Graduation_Year__c = 2019,
        Years_of_Experience__c = 5.5,
        Skills__c = 'Python, Flask, AWS Lambda, DynamoDB, CI/CD, Terraform, Serverless',
        Resume_Link__c = 'https://example.com/resumes/george-brooks',
        Candidate_Status__c = 'New'
    ),
    new Candidate__c(
        Candidate_Name__c = 'Hannah Patel',
        Email__c = 'hannah.patel@example.com',
        Phone__c = '555-010-1008',
        Location__c = 'Atlanta, GA',
        Highest_Qualification__c = 'BS in Computer Science',
        University__c = 'Georgia Institute of Technology',
        Graduation_Year__c = 2017,
        Years_of_Experience__c = 7.0,
        Skills__c = 'Java 21, Spring Cloud, Hibernate, Distributed Systems, Oracle, Kubernetes',
        Resume_Link__c = 'https://example.com/resumes/hannah-patel',
        Candidate_Status__c = 'New'
    ),
    new Candidate__c(
        Candidate_Name__c = 'Ian Cooper',
        Email__c = 'ian.cooper@example.com',
        Phone__c = '555-010-1009',
        Location__c = 'Los Angeles, CA',
        Highest_Qualification__c = 'BS in Data Science',
        University__c = 'UCLA',
        Graduation_Year__c = 2023,
        Years_of_Experience__c = 2.0,
        Skills__c = 'SQL, Python, Snowflake, dbt, Looker, Excel, Statistics',
        Resume_Link__c = 'https://example.com/resumes/ian-cooper',
        Candidate_Status__c = 'New'
    ),
    new Candidate__c(
        Candidate_Name__c = 'Julia Ramirez',
        Email__c = 'julia.ramirez@example.com',
        Phone__c = '555-010-1010',
        Location__c = 'San Diego, CA',
        Highest_Qualification__c = 'BS in Computer Science',
        University__c = 'UC San Diego',
        Graduation_Year__c = 2021,
        Years_of_Experience__c = 3.5,
        Skills__c = 'Full-stack TypeScript, React, Go, Docker, PostgreSQL, REST APIs',
        Resume_Link__c = 'https://example.com/resumes/julia-ramirez',
        Candidate_Status__c = 'New'
    )
};
insert candidates;
System.debug('Inserted ' + candidates.size() + ' Candidates.');

System.debug('--- Creating Job Applications ---');
List<Job_Application__c> apps = new List<Job_Application__c>{
    // App 1: Alex Morgan -> AI/ML
    new Job_Application__c(
        Name = 'Alex Morgan - AI/ML Engineer',
        Candidate__c = candidates[0].Id,
        Job_Requisition__c = requisitions[0].Id,
        Application_Date__c = Date.today().addDays(-12),
        Application_Status__c = 'Interview Scheduled',
        Recruiter__c = currentUserId,
        Screening_Score__c = 94.50,
        Recruiter_Notes__c = 'Impressive portfolio in generative AI and LLM architecture.'
    ),
    // App 2: Brenda Vance -> Python Dev
    new Job_Application__c(
        Name = 'Brenda Vance - Python Developer',
        Candidate__c = candidates[1].Id,
        Job_Requisition__c = requisitions[1].Id,
        Application_Date__c = Date.today().addDays(-10),
        Application_Status__c = 'Under Review',
        Recruiter__c = currentUserId,
        Screening_Score__c = 85.00,
        Recruiter_Notes__c = 'Solid microservice and FastAPI background.'
    ),
    // App 3: Carlos Mendez -> Java Dev
    new Job_Application__c(
        Name = 'Carlos Mendez - Java Developer',
        Candidate__c = candidates[2].Id,
        Job_Requisition__c = requisitions[2].Id,
        Application_Date__c = Date.today().addDays(-8),
        Application_Status__c = 'Shortlisted',
        Recruiter__c = currentUserId,
        Screening_Score__c = 91.00,
        Recruiter_Notes__c = 'Extensive experience in Kafka and enterprise banking applications.'
    ),
    // App 4: Diana Chen -> Data Analyst
    new Job_Application__c(
        Name = 'Diana Chen - Data Analyst',
        Candidate__c = candidates[3].Id,
        Job_Requisition__c = requisitions[3].Id,
        Application_Date__c = Date.today().addDays(-15),
        Application_Status__c = 'Selected',
        Recruiter__c = currentUserId,
        Screening_Score__c = 98.00,
        Recruiter_Notes__c = 'Top scorer in the analytics challenge. Excellent stakeholder communication.'
    ),
    // App 5: Ethan Walker -> SWE
    new Job_Application__c(
        Name = 'Ethan Walker - Software Engineer',
        Candidate__c = candidates[4].Id,
        Job_Requisition__c = requisitions[4].Id,
        Application_Date__c = Date.today().addDays(-4),
        Application_Status__c = 'Applied',
        Recruiter__c = currentUserId,
        Screening_Score__c = 82.50,
        Recruiter_Notes__c = 'Recent application, undergoing initial automated screening.'
    ),
    // App 6: Fiona Gallagher -> AI/ML
    new Job_Application__c(
        Name = 'Fiona Gallagher - AI/ML Engineer',
        Candidate__c = candidates[5].Id,
        Job_Requisition__c = requisitions[0].Id,
        Application_Date__c = Date.today().addDays(-14),
        Application_Status__c = 'Shortlisted',
        Recruiter__c = currentUserId,
        Screening_Score__c = 89.50,
        Recruiter_Notes__c = 'Strong deep learning foundations, CV and PyTorch expertise.'
    ),
    // App 7: George Brooks -> Python Dev
    new Job_Application__c(
        Name = 'George Brooks - Python Developer',
        Candidate__c = candidates[6].Id,
        Job_Requisition__c = requisitions[1].Id,
        Application_Date__c = Date.today().addDays(-9),
        Application_Status__c = 'Interview Scheduled',
        Recruiter__c = currentUserId,
        Screening_Score__c = 88.00,
        Recruiter_Notes__c = 'Hands-on cloud architecture and serverless specialist.'
    ),
    // App 8: Hannah Patel -> Java Dev
    new Job_Application__c(
        Name = 'Hannah Patel - Java Developer',
        Candidate__c = candidates[7].Id,
        Job_Requisition__c = requisitions[2].Id,
        Application_Date__c = Date.today().addDays(-18),
        Application_Status__c = 'Selected',
        Recruiter__c = currentUserId,
        Screening_Score__c = 96.50,
        Recruiter_Notes__c = 'Senior technical powerhouse with exceptional distributed systems track record.'
    ),
    // App 9: Ian Cooper -> Data Analyst
    new Job_Application__c(
        Name = 'Ian Cooper - Data Analyst',
        Candidate__c = candidates[8].Id,
        Job_Requisition__c = requisitions[3].Id,
        Application_Date__c = Date.today().addDays(-2),
        Application_Status__c = 'Applied',
        Recruiter__c = currentUserId,
        Screening_Score__c = 78.00,
        Recruiter_Notes__c = 'Entry-level candidate with good academic credentials.'
    ),
    // App 10: Julia Ramirez -> SWE
    new Job_Application__c(
        Name = 'Julia Ramirez - Software Engineer',
        Candidate__c = candidates[9].Id,
        Job_Requisition__c = requisitions[4].Id,
        Application_Date__c = Date.today().addDays(-5),
        Application_Status__c = 'Under Review',
        Recruiter__c = currentUserId,
        Screening_Score__c = 84.00,
        Recruiter_Notes__c = 'Strong full-stack portfolio in React and TypeScript.'
    ),
    // App 11: Alex Morgan -> SWE
    new Job_Application__c(
        Name = 'Alex Morgan - Software Engineer',
        Candidate__c = candidates[0].Id,
        Job_Requisition__c = requisitions[4].Id,
        Application_Date__c = Date.today().addDays(-16),
        Application_Status__c = 'Interviewed',
        Recruiter__c = currentUserId,
        Screening_Score__c = 90.00,
        Recruiter_Notes__c = 'Cross-applying for senior engineering track.'
    ),
    // App 12: Carlos Mendez -> SWE
    new Job_Application__c(
        Name = 'Carlos Mendez - Software Engineer',
        Candidate__c = candidates[2].Id,
        Job_Requisition__c = requisitions[4].Id,
        Application_Date__c = Date.today().addDays(-11),
        Application_Status__c = 'Interviewed',
        Recruiter__c = currentUserId,
        Screening_Score__c = 87.00,
        Recruiter_Notes__c = 'Completed initial technical round.'
    )
};
insert apps;
System.debug('Inserted ' + apps.size() + ' Job Applications.');

System.debug('--- Creating Interviews ---');
List<Interview__c> interviews = new List<Interview__c>{
    // 1. Upcoming Technical for Alex Morgan
    new Interview__c(
        Interview_Name__c = 'Round 1 Technical Screening',
        Job_Application__c = apps[0].Id,
        Candidate__c = candidates[0].Id,
        Interviewer__c = currentUserId,
        Interview_Date__c = DateTime.now().addDays(2),
        Interview_Type__c = 'Technical',
        Interview_Status__c = 'Scheduled'
    ),
    // 2. Upcoming Technical for George Brooks
    new Interview__c(
        Interview_Name__c = 'Python Architecture & Coding',
        Job_Application__c = apps[6].Id,
        Candidate__c = candidates[6].Id,
        Interviewer__c = currentUserId,
        Interview_Date__c = DateTime.now().addDays(3),
        Interview_Type__c = 'Technical',
        Interview_Status__c = 'Scheduled'
    ),
    // 3. Completed for Diana Chen
    new Interview__c(
        Interview_Name__c = 'Data Analytics Case Study',
        Job_Application__c = apps[3].Id,
        Candidate__c = candidates[3].Id,
        Interviewer__c = currentUserId,
        Interview_Date__c = DateTime.now().addDays(-3),
        Interview_Type__c = 'Technical',
        Interview_Status__c = 'Completed',
        Interview_Score__c = 96.00,
        Recommendation__c = 'Strong Hire',
        Interview_Feedback__c = 'Outstanding SQL and analytics mastery. Clear presentation of statistical concepts.'
    ),
    // 4. Completed for Hannah Patel
    new Interview__c(
        Interview_Name__c = 'Final Architectural Interview',
        Job_Application__c = apps[7].Id,
        Candidate__c = candidates[7].Id,
        Interviewer__c = currentUserId,
        Interview_Date__c = DateTime.now().addDays(-2),
        Interview_Type__c = 'Final',
        Interview_Status__c = 'Completed',
        Interview_Score__c = 95.00,
        Recommendation__c = 'Strong Hire',
        Interview_Feedback__c = 'Superb knowledge of enterprise distributed caching and Kafka message broker patterns.'
    ),
    // 5. Completed for Carlos Mendez
    new Interview__c(
        Interview_Name__c = 'HR & Culture Fit Round',
        Job_Application__c = apps[11].Id,
        Candidate__c = candidates[2].Id,
        Interviewer__c = currentUserId,
        Interview_Date__c = DateTime.now().addDays(-1),
        Interview_Type__c = 'HR',
        Interview_Status__c = 'Completed',
        Interview_Score__c = 88.00,
        Recommendation__c = 'Hire',
        Interview_Feedback__c = 'Great collaborative demeanor, strong team player with mature communication skills.'
    )
};
insert interviews;
System.debug('Inserted ' + interviews.size() + ' Interviews.');
System.debug('=== Sample Data Generation Complete ===');
