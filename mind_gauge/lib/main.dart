import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // Keeping http import for future API calls
import 'firebase_options.dart';
// --- CONFIGURATION ---
// Global instance of FirebaseAuth
final FirebaseAuth _auth = FirebaseAuth.instance;
// const String _apiBaseUrl = 'http://10.0.2.2:5000'; // Define API URL if needed later

// --- SERVICE LAYER AND DATA STRUCTURES ---

class UserProfile {
  final String email;
  final String name;
  final String userId;
  final int age;
  final String location;

  UserProfile({required this.email, required this.name, required this.userId, required this.age, required this.location});

  factory UserProfile.fromDatabase(Map<String, dynamic> data, User user) {
    return UserProfile(
      email: user.email ?? '',
      name: data['name'] as String,
      userId: user.uid,
      age: data['age'] as int,
      location: data['location'] as String,
    );
  }
}

class FirebaseUserService {
  // MOCK: This map simulates a Firestore/Realtime Database collection
  static final Map<String, Map<String, dynamic>> _userDbMock = {};

  Future<void> saveUserDetails(String userId, String name, int age, String location) async {
    await Future.delayed(const Duration(milliseconds: 200)); 
    _userDbMock[userId] = {
      'name': name,
      'age': age,
      'location': location,
    };
  }

  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200)); 
    return _userDbMock[userId];
  }
}

class AuthService {
  final FirebaseUserService _userService = FirebaseUserService();
  
  // --- LOGIN WITH FIREBASE AUTH ---
  Future<UserProfile?> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        final userData = await _userService.getUserDetails(user.uid);
        
        if (userData != null) {
          return UserProfile.fromDatabase(userData, user);
        }
      }
      return null;

    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw 'An unknown error occurred.';
    }
  }

  // --- REGISTER WITH FIREBASE AUTH ---
  Future<UserProfile> register({
    required String email, 
    required String password, 
    required String name, 
    required int age, 
    required String location,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;

      await _userService.saveUserDetails(user.uid, name, age, location);
      
      return UserProfile(
        email: email,
        name: name,
        userId: user.uid,
        age: age,
        location: location,
      );

    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw 'An unknown error occurred.';
    }
  }
}


// Data structure for the static domain metadata
class DomainMetadata {
  final String domainName;
  final int thresholdScore; 
  final String Level2AdultMeasure;

  const DomainMetadata(this.domainName, this.thresholdScore, this.Level2AdultMeasure);
}

abstract class BaseQuestionnaireData {
  final String domain;
  final String questionNumber;
  final String questionText;
  double score;

  BaseQuestionnaireData({
    required this.domain, 
    required this.questionNumber, 
    required this.questionText, 
    required this.score,
  });
}

class QuestionnaireData extends BaseQuestionnaireData {
  QuestionnaireData(String domain, String questionNumber, String questionText) : super(
    domain: domain, 
    questionNumber: questionNumber, 
    questionText: questionText, 
    score: 0.0
  );
}

class Level2AdultQuestionnaireData extends BaseQuestionnaireData {
  Level2AdultQuestionnaireData(String domain, String questionNumber, String questionText) : super(
    domain: domain, 
    questionNumber: questionNumber, 
    questionText: questionText, 
    score: 0.0
  );
}
class Level2AdolescentQuestionnaireData extends BaseQuestionnaireData {
  Level2AdolescentQuestionnaireData(String domain, String questionNumber, String questionText) : super(
    domain: domain, 
    questionNumber: questionNumber, 
    questionText: questionText, 
    score: 0.0
  );
}
class DomainScore {
  final String domain;
  final String domainName;
  final int highestScore;
  final int thresholdScore; 
  final String Level2AdultMeasure;

  DomainScore(this.domain, this.domainName, this.highestScore, this.thresholdScore, this.Level2AdultMeasure);

  String get severity {
    switch (highestScore) {
      case 4: return "Severe";
      case 3: return "Moderate";
      case 2: return "Mild";
      case 1: return "Slight";
      default: return "None";
    }
  }

  @override
  String toString() {
    return "${domainName}: ${severity} (Score: $highestScore). Follow-up needed: ${Level2AdultMeasure}";
  }
}

// NEW ENUM: Define types for age-based mapping
enum QuestionnaireType { adultLevel1, adolescentLevel1 }

class MockQuestionnaireService {
  static const Map<String, DomainMetadata> _domainThresholds = {
    "I": DomainMetadata("Depression", 2, "LEVEL 2-Depression-Adult (PROMIS Emotional Distress-Depression-Short Form)"),
    "II": DomainMetadata("Anger", 2, "LEVEL 2-Anger-Adult (PROMIS Emotional Distress-Anger-Short Form)"),
    "III": DomainMetadata("Mania", 2, "LEVEL 2-Mania-Adult (Altman Self-Rating Mania Scale)"),
    "IV": DomainMetadata("Anxiety", 2, "LEVEL 2-Anxiety-Adult (PROMIS Emotional Distress-Anxiety-Short Form)"),
    "V": DomainMetadata("Somatic Symptoms", 2, "LEVEL 2-Somatic Symptom-Adult (Patient Health Questionnaire 15 Somatic Symptom Severity [PHQ-15])"),
    "VI": DomainMetadata("Suicidal Ideation", 1, "None"),
    "VII": DomainMetadata("Psychosis", 1, "None"),
    "VIII": DomainMetadata("Sleep Problems", 2, "LEVEL 2-Sleep Disturbance - Adult (PROMIS-Sleep Disturbance-Short Form)"),
    "IX": DomainMetadata("Memory", 2, "None"),
    "X": DomainMetadata("Repetitive Thoughts and Behaviors", 2, "LEVEL 2-Repetitive Thoughts and Behaviors-Adult (adapted from the Florida Obsessive-Compulsive Inventory [FOCI] Severity Scale [Part B])"),
    "XI": DomainMetadata("Dissociation", 2, "None"),
    "XII": DomainMetadata("Personality Functioning", 2, "None"),
    "XIII": DomainMetadata("Substance Use", 1, "LEVEL 2-Substance Abuse-Adult (adapted from the NIDA-modified ASSIST)"),
  };
// NEW: Threshold data for Adolescent Level 1 (Age 11-17)
  static const Map<String, DomainMetadata> _adolescentDomainThresholds = {
    "I": DomainMetadata("Somatic Symptoms", 2, "LEVEL 2—Somatic Symptom—Child Age 11–17"),
    "II": DomainMetadata("Sleep Problems", 2, "LEVEL 2—Sleep Disturbance—Child Age 11–17"),
    "III": DomainMetadata("Inattention", 1, "None"), 
    "IV": DomainMetadata("Depression", 2, "LEVEL 2—Depression—Child Age 11–17"),
    "V": DomainMetadata("Anger", 2, "LEVEL 2—Anger—Child Age 11–17"),
    "VI": DomainMetadata("Irritability", 2, "LEVEL 2—Irritability—Child Age 11–17"),
    "VII": DomainMetadata("Mania", 2, "LEVEL 2—Mania—Child Age 11–17"),
    "VIII": DomainMetadata("Anxiety", 2, "LEVEL 2—Anxiety—Child Age 11–17"),
    "IX": DomainMetadata("Psychosis", 1, "None"), 
    "X": DomainMetadata("Repetitive Thoughts and Behaviors", 2, "LEVEL 2—Repetitive Thoughts and Behaviors—Child Age 11–17"),
    "XI": DomainMetadata("Substance Use", 1, "LEVEL 2—Substance Use—Child Age 11–17"), 
    "XII": DomainMetadata("Suicidal Ideation", 1, "None"), 
  };
  // CHANGE: Renamed original method to handle Adult questions
  static List<QuestionnaireData> getAdultLevel1Questions() {
    return [
      QuestionnaireData("I", "1", "Little interest or pleasure in doing things?"),
      QuestionnaireData("I", "2", "Feeling down, depressed, or hopeless?"),
      QuestionnaireData("II", "3", "Feeling more irritated, grouchy, or angry than usual?"),
      QuestionnaireData("III", "4", "Sleeping less than usual, but still have a lot of energy?"),
      QuestionnaireData("III", "5", "Starting lots more projects than usual or doing more risky things than usual?"),
      QuestionnaireData("IV", "6", "Feeling nervous, anxious, frightened, worried, or on edge?"),
      QuestionnaireData("IV", "7", "Feeling panic or being frightened?"),
      QuestionnaireData("IV", "8", "Avoiding situations that make you anxious?"),
      QuestionnaireData("V", "9", "Unexplained aches and pains (e.g., head, back, joints, abdomen, legs)?"),
      QuestionnaireData("V", "10", "Feeling that your illnesses are not being taken seriously enough?"),
      QuestionnaireData("VI", "11", "Thoughts of actually hurting yourself?"),
      QuestionnaireData("VII", "12", "Hearing things other people couldn't hear, such as voices even when no one was around?"),
      QuestionnaireData("VII", "13", "Feeling that someone could hear your thoughts, or that you could hear what another person was thinking?"),
      QuestionnaireData("VIII", "14", "Problems with sleep that affected your sleep quality over all?"),
      QuestionnaireData("IX", "15", "Problems with memory (e.g., learning new information) or with location (e.g., finding your way home)?"),
      QuestionnaireData("X", "16", "Unpleasant thoughts, urges, or images that repeatedly enter your mind?"),
      QuestionnaireData("X", "17", "Feeling driven to perform certain behaviors or mental acts over and over again?"),
      QuestionnaireData("XI", "18", "Feeling detached or distant from yourself, your body, your physical surroundings, or your memories?"),
      QuestionnaireData("XII", "19", "Not knowing who you really are or what you want out of life?"),
      QuestionnaireData("XII", "20", "Not feeling close to other people or enjoying your relationships with them?"),
      QuestionnaireData("XIII", "21", "Drinking at least 4 drinks of any kind of alcohol in a single day?"),
      QuestionnaireData("XIII", "22", "Smoking any cigarettes, a cigar, or pipe, or using snuff or chewing tobacco?"),
      QuestionnaireData("XIII", "23", "Using any of the following medicines on your own, that is, without a doctor's prescription, in greater amounts or longer than prescribed [e.g., painkillers (like Vicodin), stimulants (like Ritalin or Adderall), sedatives or tranquilizers (like sleeping pills or Valium), or drugs like marijuana, cocaine or crack, club drugs (like ecstasy), hallucinogens (like LSD), heroin, inhalants or solvents (like glue), or methamphetamine (like speed)]?"),
    ];
  }

  // NEW: Mock list for Adolescent Level 1 questions
  static List<QuestionnaireData> getAdolescentLevel1Questions() {
    return [
      QuestionnaireData("I", "1", "Been bothered by stomachaches, headaches, or other aches and pains?"),
      QuestionnaireData("I", "2", "Worried about your health or about getting sick?"),
      QuestionnaireData("II", "3", "Been bothered by not being able to fall asleep or stay asleep?"),
      QuestionnaireData("III", "4", "Been bothered by not being able to pay attention when in class or doing homework?"),
      QuestionnaireData("IV", "5", "Had less fun doing things than you used to?"),
      QuestionnaireData("IV", "6", "Felt sad or depressed for several hours?"),
      QuestionnaireData("V", "7", "Felt more irritated or easily annoyed than usual?"),
      // Note: Irritability (VI) and Anger (V) are often paired in this measure
      QuestionnaireData("VI", "8", "Felt angry or lost your temper?"),
      QuestionnaireData("VII", "9", "Started lots more projects than usual?"),
      QuestionnaireData("VII", "10", "Slept less than usual but still had a lot of energy?"),
      QuestionnaireData("VIII", "11", "Felt nervous, anxious, or scared?"),
      QuestionnaireData("VIII", "12", "Not been able to stop worrying?"),
      QuestionnaireData("VIII", "13", "Not been able to do things because they made you feel nervous?"),
      QuestionnaireData("IX", "14", "Heard voices that no one else could hear?"),
      QuestionnaireData("IX", "15", "Had visions when you were completely awake?"),
      QuestionnaireData("X", "16", "Thoughts that you would do something bad or something bad would happen?"),
      QuestionnaireData("X", "17", "Felt the need to check on things over and over again?"),
      QuestionnaireData("X", "18", "Worried a lot about things being dirty or having germs?"),
      QuestionnaireData("X", "19", "Felt you had to do things in a certain way to keep something bad from happening?"),
      // Substance use questions usually have a threshold of 1 (Slight/Yes)
      QuestionnaireData("XI", "20", "Had an alcoholic beverage (beer, wine, liquor)?"),
      QuestionnaireData("XI", "21", "Smoked a cigarette, cigar, or pipe?"),
      QuestionnaireData("XI", "22", "Used drugs like marijuana, cocaine, or club drugs?"),
      QuestionnaireData("XI", "23", "Used medicine without a doctor's prescription to get high?"),
      QuestionnaireData("XII", "24", "Thought about killing yourself or committing suicide?"),
      QuestionnaireData("XII", "25", "Have you EVER tried to kill yourself?"),
    ];
  }

  // NEW: Function to map age to the correct questionnaire type
  static QuestionnaireType mapAgeToQuestionnaire(int age) {
    if (age >= 18) {
      return QuestionnaireType.adultLevel1;
    } else if (age >= 11) { 
      return QuestionnaireType.adolescentLevel1;
    }
    return QuestionnaireType.adultLevel1; // Default
  }

  // NEW: Function to get the correct questions based on age
  static List<QuestionnaireData> getLevel1Questions(int age) {
    final type = mapAgeToQuestionnaire(age);
    if (type == QuestionnaireType.adultLevel1) {
      return getAdultLevel1Questions();
    } else if (type == QuestionnaireType.adolescentLevel1) {
      return getAdolescentLevel1Questions(); 
    }
    return getAdultLevel1Questions();
  }

  Future<List<DomainScore>> submitQuestionnaire(List<QuestionnaireData> responses,int age) async {
    await Future.delayed(const Duration(seconds: 1));
    final isAdolescent = mapAgeToQuestionnaire(age) == QuestionnaireType.adolescentLevel1;
    final thresholdMap = isAdolescent ? _adolescentDomainThresholds : _domainThresholds;
    final Map<String, int> domainHighestScores = {};

    for (var item in responses) {
      final domain = item.domain;
      final score = item.score.round(); 
      
      domainHighestScores[domain] = 
        (domainHighestScores[domain] == null || score > domainHighestScores[domain]!)
        ? score
        : domainHighestScores[domain]!;
    }
    
    final List<DomainScore> results = [];

    domainHighestScores.forEach((domain, highestScore) {
      final metadata = _domainThresholds[domain];
      if (metadata == null) return;

      bool requiresFollowUp = highestScore >= metadata.thresholdScore;

      if (requiresFollowUp) {
      results.add(DomainScore(
        domain,
        metadata.domainName,
        highestScore,
        metadata.thresholdScore,
        metadata.Level2AdultMeasure,
      ));
      }
    });

    results.sort((a, b) => b.highestScore.compareTo(a.highestScore));

    return results;
  }
  
  static final Map<String, List<Level2AdultQuestionnaireData>> _level2AdultQuestions = {
    "Depression": [
      Level2AdultQuestionnaireData("I", "D1", "I felt depressed."),
      Level2AdultQuestionnaireData("I", "D2", "I felt worthless."),
      Level2AdultQuestionnaireData("I", "D3", "I felt sad."),
      Level2AdultQuestionnaireData("I", "D4", "I felt hopeless."),
      Level2AdultQuestionnaireData("I", "D5", "I felt like a failure."),
      Level2AdultQuestionnaireData("I", "D6", "I felt that I have no future."),
      Level2AdultQuestionnaireData("I", "D7", "I felt helpless."),
      Level2AdultQuestionnaireData("I", "D8", "I felt discouraged."),
    ],
    "Anger": [
      Level2AdultQuestionnaireData("II", "A1", "In the past seven days were you irritated more than people knew?"),
      Level2AdultQuestionnaireData("II", "A2", "In the past seven days, have you felt angry?"),
      Level2AdultQuestionnaireData("II", "A3", " In the past seven days, have you felt like you were ready to explode?"),
      Level2AdultQuestionnaireData("II", "A4", "In the past seven days, were you grouchy?"),
      Level2AdultQuestionnaireData("II", "A5", "In the past seven days, have you felt annoyed?"),
    ],
    "Anxiety": [
      Level2AdultQuestionnaireData("IV", "AN1", "In the past seven days, have you felt fearful?"),
      Level2AdultQuestionnaireData("IV", "AN2", "In the past seven days, have you felt anxious?"),
      Level2AdultQuestionnaireData("IV", "AN3", "In the past seven days, have you felt worried?"),
      Level2AdultQuestionnaireData("IV", "AN4", "In the past seven days, have you found it hard to focus on anything other than my anxiety?"),
      Level2AdultQuestionnaireData("IV", "AN5", "In the past seven days, have you felt nervous?"),
      Level2AdultQuestionnaireData("IV", "AN6", "In the past seven days, have you felt uneasy?"),
      Level2AdultQuestionnaireData("IV", "AN7", "In the past seven days, have you felt tense?"),
    ],
    "Somatic Symptoms": [
      Level2AdultQuestionnaireData("V", "S1", "During the past 7 days, how much have you been bothered by Stomach Pain?"),
      Level2AdultQuestionnaireData("V", "S2", "During the past 7 days, how much have you been bothered by Back Pain?"),
      Level2AdultQuestionnaireData("V", "S3", "During the past 7 days, how much have you been bothered by Pain in your arms,legs,or joints(knees,hips,etc.)?"),
      Level2AdultQuestionnaireData("V", "S4", "During the past 7 days, how much have you been bothered by Menstrual cramps or other problems with your periods(WOMEN ONLY)?"),
      Level2AdultQuestionnaireData("V", "S5", "During the past 7 days, how much have you been bothered by Headaches?"),
      Level2AdultQuestionnaireData("V", "S6", " During the past 7 days, how much have you been bothered by Chest Pain?"),
      Level2AdultQuestionnaireData("V", "S7", "During the past 7 days, how much have you been bothered by Dizziness?"),
      Level2AdultQuestionnaireData("V", "S8", "During the past 7 days, how much have you been bothered by Fainting Spells?"),
      Level2AdultQuestionnaireData("V", "S9", "During the past 7 days, how much have you been bothered by Feeling your heart pound or race?"),
      Level2AdultQuestionnaireData("V", "S10", " During the past 7 days, how much have you been bothered by Shortness of breath?"),
      Level2AdultQuestionnaireData("V", "S11", "During the past 7 days, how much have you been bothered by pain or problems during sexual intercourse?"),
      Level2AdultQuestionnaireData("V", "S12", "During the past 7 days, how much have you been bothered by constipation,loose bowels or diarrhea?"),
      Level2AdultQuestionnaireData("V", "S13", " During the past 7 days, how much have you been bothered by Nausea,gas or indigestion?"),
      Level2AdultQuestionnaireData("V", "S14", "During the past 7 days, how much have you been bothered by feeling tired or having low energy?"),
      Level2AdultQuestionnaireData("V", "S15", "During the past 7 days, how much have you been bothered by trouble sleeping?"),
    ],
    "Sleep Problems": [
      Level2AdultQuestionnaireData("VIII", "SD1", "In the past seven days, was your sleep restless?"),
      Level2AdultQuestionnaireData("VIII", "SD2", "In the past seven days, were you satisfied with your sleep?"),
      Level2AdultQuestionnaireData("VIII", "SD3", "In the past seven days, was your sleep refreshing?"),
      Level2AdultQuestionnaireData("VIII", "SD4", "In the past seven days, have you had difficulty falling asleep?"),
      Level2AdultQuestionnaireData("VIII", "SD5", "In the past seven days, have you had trouble staying asleep?"),
      Level2AdultQuestionnaireData("VIII", "SD6", "In the past seven days, have you had trouble sleeping"),
      Level2AdultQuestionnaireData("VIII", "SD7", "In the past seven days, have you got enough sleep?"),
      Level2AdultQuestionnaireData("VIII", "SD8", " In the past seven days, how was your sleep quality?"),
    ],
    "Repetitive Thoughts and Behaviors": [
      Level2AdultQuestionnaireData("X", "R1", "On average, how much time is occupied by unwanted thoughts or behaviours each day?"),
      Level2AdultQuestionnaireData("X", "R2", " How much distress do these thoughts or behaviours cause you?"),
      Level2AdultQuestionnaireData("X", "R3", "How hard is it for you to control these thoughts or behaviours?"),
      Level2AdultQuestionnaireData("X", "R4", "How much do these thoughts or behaviours cause you to avoid doing anything , going any place, or being with anyone?"),
      Level2AdultQuestionnaireData("X", "R5", "How much do these thoughts or behaviours interfere with school,work,or your social or family life?"),
    ],
    "Substance Use": [
      Level2AdultQuestionnaireData("XIII", "SU1", "During the past TWO WEEKS, about how often did you use Painkillers(like Vicodin) ON YOUR OWN, that is, without a doctor’s prescription, in greater amounts or longer than prescribed?"),
      Level2AdultQuestionnaireData("XIII", "SU2", "During the past TWO WEEKS, about how often did you use Stimulants(like Ritalin,Adderall) ON YOUR OWN, that is, without a doctor’s prescription, in greater amounts or longer than prescribed?"),
      Level2AdultQuestionnaireData("XIII", "SU3", "During the past TWO WEEKS, about how often did you use Sedatives or tranquilizers (like sleeping pills or Valium) ON YOUR OWN, that is, without a doctor’s prescription, in greater amounts or longer than prescribed?"),
      Level2AdultQuestionnaireData("XIII", "SU4", "During the past TWO WEEKS, about how often did you use Marijuana?"),
      Level2AdultQuestionnaireData("XIII", "SU5", "During the past TWO WEEKS, about how often did you use Cocaine or crack?"),
      Level2AdultQuestionnaireData("XIII", "SU6", "During the past TWO WEEKS, about how often did you use Club drugs (like ecstasy)?"),
      Level2AdultQuestionnaireData("XIII", "SU7", "During the past TWO WEEKS, about how often did you use Hallucinogens (like LSD)?"),
      Level2AdultQuestionnaireData("XIII", "SU8", "During the past TWO WEEKS, about how often did you use Heroin?"),
      Level2AdultQuestionnaireData("XIII", "SU9", "During the past TWO WEEKS, about how often did you use Inhalants or solvents (like glue)?"),
      Level2AdultQuestionnaireData("XIII", "SU10", "During the past TWO WEEKS, about how often did you use Methamphetamine (like speed)"),
    ],
  };
static final Map<String, List<Level2AdolescentQuestionnaireData>> _level2AdolescentQuestions = {
    "Somatic Symptoms": [
      Level2AdolescentQuestionnaireData("1", "S1", "During the past 7 days, how much have you been bothered by Stomach pain? [cite: 5, 6]"),
      Level2AdolescentQuestionnaireData("1", "S2", "During the past 7 days, how much have you been bothered by Back pain? [cite: 5, 7]"),
      Level2AdolescentQuestionnaireData("1", "S3", "During the past 7 days, how much have you been bothered by Pain in your arms, legs, or joints (knees, hips, etc.)? [cite: 5, 8]"),
      Level2AdolescentQuestionnaireData("1", "S4", "During the past 7 days, how much have you been bothered by Headaches? [cite: 5, 9]"),
      Level2AdolescentQuestionnaireData("1", "S5", "During the past 7 days, how much have you been bothered by Chest pain? [cite: 5, 10]"),
      Level2AdolescentQuestionnaireData("1", "S6", "During the past 7 days, how much have you been bothered by Dizziness? [cite: 5, 11]"),
      Level2AdolescentQuestionnaireData("1", "S7", "During the past 7 days, how much have you been bothered by Fainting spells? [cite: 5, 12]"),
      Level2AdolescentQuestionnaireData("1", "S8", "During the past 7 days, how much have you been bothered by Feeling your heart pound or race? [cite: 5, 13]"),
      Level2AdolescentQuestionnaireData("1", "S9", "During the past 7 days, how much have you been bothered by Shortness of breath? [cite: 5, 14]"),
      Level2AdolescentQuestionnaireData("1", "S10", "During the past 7 days, how much have you been bothered by Constipation, loose bowels, or diarrhea? [cite: 5, 15]"),
      Level2AdolescentQuestionnaireData("1", "S11", "During the past 7 days, how much have you been bothered by Nausea, gas, or indigestion? [cite: 5, 16]"),
      Level2AdolescentQuestionnaireData("1", "S12", "During the past 7 days, how much have you been bothered by Feeling tired or having low energy? [cite: 5, 17]"),
      Level2AdolescentQuestionnaireData("1", "S13", "During the past 7 days, how much have you been bothered by Trouble sleeping? [cite: 5, 18]"),
    ],
    "Sleep Problems": [
      Level2AdolescentQuestionnaireData("2", "SD1", "In the past SEVEN (7) DAYS, my sleep was restless. [cite: 22, 23]"),
      Level2AdolescentQuestionnaireData("2", "SD2", "In the past SEVEN (7) DAYS, I was satisfied with my sleep. [cite: 22, 24]"),
      Level2AdolescentQuestionnaireData("2", "SD3", "In the past SEVEN (7) DAYS, my sleep was refreshing. [cite: 22, 25]"),
      Level2AdolescentQuestionnaireData("2", "SD4", "In the past SEVEN (7) DAYS, I had difficulty falling asleep. [cite: 22, 26]"),
      Level2AdolescentQuestionnaireData("2", "SD5", "In the past SEVEN (7) DAYS, I had trouble staying asleep. [cite: 22, 27]"),
      Level2AdolescentQuestionnaireData("2", "SD6", "In the past SEVEN (7) DAYS, I had trouble sleeping. [cite: 22, 28]"),
      Level2AdolescentQuestionnaireData("2", "SD7", "In the past SEVEN (7) DAYS, I got enough sleep. [cite: 22, 29]"),
      Level2AdolescentQuestionnaireData("2", "SD8", "In the past SEVEN (7) DAYS, my sleep quality was... [cite: 22, 30]"),
    ],
    "Depression": [
      Level2AdolescentQuestionnaireData("3", "D1", "In the past SEVEN (7) DAYS, I could not stop feeling sad. [cite: 33, 34]"),
      Level2AdolescentQuestionnaireData("3", "D2", "In the past SEVEN (7) DAYS, I felt alone. [cite: 33, 35]"),
      Level2AdolescentQuestionnaireData("3", "D3", "In the past SEVEN (7) DAYS, I felt everything in my life went wrong. [cite: 33, 36]"),
      Level2AdolescentQuestionnaireData("3", "D4", "In the past SEVEN (7) DAYS, I felt like I couldn't do anything right. [cite: 33, 37]"),
      Level2AdolescentQuestionnaireData("3", "D5", "In the past SEVEN (7) DAYS, I felt lonely. [cite: 33, 38]"),
      Level2AdolescentQuestionnaireData("3", "D6", "In the past SEVEN (7) DAYS, I felt sad. [cite: 33, 39]"),
      Level2AdolescentQuestionnaireData("3", "D7", "In the past SEVEN (7) DAYS, I felt unhappy. [cite: 33, 40]"),
      Level2AdolescentQuestionnaireData("3", "D8", "In the past SEVEN (7) DAYS, I thought that my life was bad. [cite: 33, 41]"),
      Level2AdolescentQuestionnaireData("3", "D9", "In the past SEVEN (7) DAYS, being sad made it hard for me to do things with my friends. [cite: 33, 42]"),
      Level2AdolescentQuestionnaireData("3", "D10", "In the past SEVEN (7) DAYS, I didn't care about anything. [cite: 33, 43]"),
      Level2AdolescentQuestionnaireData("3", "D11", "In the past SEVEN (7) DAYS, I felt stressed. [cite: 33, 45]"),
      Level2AdolescentQuestionnaireData("3", "D12", "In the past SEVEN (7) DAYS, I felt too sad to eat. [cite: 33, 46]"),
      Level2AdolescentQuestionnaireData("3", "D13", "In the past SEVEN (7) DAYS, I wanted to be by myself. [cite: 33, 47]"),
      Level2AdolescentQuestionnaireData("3", "D14", "In the past SEVEN (7) DAYS, it was hard for me to have fun. [cite: 33, 48]"),
    ],
    "Anger": [
      Level2AdolescentQuestionnaireData("4", "A1", "In the past SEVEN (7) DAYS, I felt mad. [cite: 51, 52]"),
      Level2AdolescentQuestionnaireData("4", "A2", "In the past SEVEN (7) DAYS, I was so angry I felt like throwing something. [cite: 51, 53]"),
      Level2AdolescentQuestionnaireData("4", "A3", "In the past SEVEN (7) DAYS, I was so angry I felt like yelling at somebody. [cite: 51, 54]"),
      Level2AdolescentQuestionnaireData("4", "A4", "In the past SEVEN (7) DAYS, when I got mad, I stayed mad. [cite: 51, 55]"),
      Level2AdolescentQuestionnaireData("4", "A5", "In the past SEVEN (7) DAYS, I felt fed up. [cite: 51, 56]"),
      Level2AdolescentQuestionnaireData("4", "A6", "In the past SEVEN (7) DAYS, I felt upset. [cite: 51, 57]"),
    ],
    "Irritability": [
      Level2AdolescentQuestionnaireData("5", "I1", "In the last SEVEN (7) DAYS, am easily annoyed by others. [cite: 60, 62]"),
      Level2AdolescentQuestionnaireData("5", "I2", "In the last SEVEN (7) DAYS, often lose my temper. [cite: 60, 63]"),
      Level2AdolescentQuestionnaireData("5", "I3", "In the last SEVEN (7) DAYS, stay angry for a long time. [cite: 60, 64]"),
      Level2AdolescentQuestionnaireData("5", "I4", "In the last SEVEN (7) DAYS, am angry most of the time. [cite: 60, 65]"),
      Level2AdolescentQuestionnaireData("5", "I5", "In the last SEVEN (7) DAYS, get angry frequently. [cite: 60, 66]"),
      Level2AdolescentQuestionnaireData("5", "I6", "In the last SEVEN (7) DAYS, lose temper easily. [cite: 60, 67]"),
      Level2AdolescentQuestionnaireData("5", "I7", "In the last SEVEN (7) DAYS, overall irritability causes me problems. [cite: 60, 68]"),
    ],
    "Mania": [
      Level2AdolescentQuestionnaireData("6", "M1", "Do you feel happier or more cheerful than usual? [cite: 70, 73]"),
      Level2AdolescentQuestionnaireData("6", "M2", "Do you feel more self-confident than usual? [cite: 70, 74]"),
      Level2AdolescentQuestionnaireData("6", "M3", "Do you need less sleep than usual? [cite: 70, 75]"),
      Level2AdolescentQuestionnaireData("6", "M4", "Do you talk more than usual? [cite: 70, 76]"),
      Level2AdolescentQuestionnaireData("6", "M5", "Have you been more active than usual? [cite: 70, 77]"),
    ],
    "Anxiety": [
      Level2AdolescentQuestionnaireData("7", "AN1", "In the past SEVEN (7) DAYS, I felt like something awful might happen. [cite: 80, 81]"),
      Level2AdolescentQuestionnaireData("7", "AN2", "In the past SEVEN (7) DAYS, I felt nervous. [cite: 80, 82]"),
      Level2AdolescentQuestionnaireData("7", "AN3", "In the past SEVEN (7) DAYS, I felt scared. [cite: 80, 83]"),
      Level2AdolescentQuestionnaireData("7", "AN4", "In the past SEVEN (7) DAYS, I felt worried. [cite: 80, 84]"),
      Level2AdolescentQuestionnaireData("7", "AN5", "In the past SEVEN (7) DAYS, I worried about what could happen to me. [cite: 80, 85]"),
      Level2AdolescentQuestionnaireData("7", "AN6", "In the past SEVEN (7) DAYS, I worried when I went to bed at night. [cite: 80, 86]"),
      Level2AdolescentQuestionnaireData("7", "AN7", "In the past SEVEN (7) DAYS, I got scared really easy. [cite: 80, 87]"),
      Level2AdolescentQuestionnaireData("7", "AN8", "In the past SEVEN (7) DAYS, I was afraid of going to school. [cite: 80, 88]"),
      Level2AdolescentQuestionnaireData("7", "AN9", "In the past SEVEN (7) DAYS, I was worried I might die. [cite: 80, 89]"),
      Level2AdolescentQuestionnaireData("7", "AN10", "In the past SEVEN (7) DAYS, I woke up at night scared. [cite: 80, 90]"),
      Level2AdolescentQuestionnaireData("7", "AN11", "In the past SEVEN (7) DAYS, I worried when I was at home. [cite: 80, 91]"),
      Level2AdolescentQuestionnaireData("7", "AN12", "In the past SEVEN (7) DAYS, I worried when I was away from home. [cite: 80, 92]"),
      Level2AdolescentQuestionnaireData("7", "AN13", "In the past SEVEN (7) DAYS, it was hard for me to relax. [cite: 80, 93]"),
    ],
    "Repetitive Thoughts and Behaviors": [
      Level2AdolescentQuestionnaireData("8", "R1", "During the past SEVEN (7) DAYS, on average, how much time is occupied by these thoughts or behaviors each day? [cite: 98, 99]"),
      Level2AdolescentQuestionnaireData("8", "R2", "During the past SEVEN (7) DAYS, how much do they bother you? [cite: 98, 100]"),
      Level2AdolescentQuestionnaireData("8", "R3", "During the past SEVEN (7) DAYS, how hard is it for you to control them? [cite: 98, 101]"),
      Level2AdolescentQuestionnaireData("8", "R4", "During the past SEVEN (7) DAYS, how much do they cause you to avoid doing things, going places or being with people? [cite: 98, 102]"),
      Level2AdolescentQuestionnaireData("8", "R5", "During the past SEVEN (7) DAYS, how much do they interfere with school, your social or family life, or your job? [cite: 98, 103]"),
    ],
    "Substance Use": [
      Level2AdolescentQuestionnaireData("9", "SU1", "During the past TWO (2) weeks, about how often did you have an alcoholic beverage (beer, wine, liquor, etc.)? [cite: 109, 110]"),
      Level2AdolescentQuestionnaireData("9", "SU2", "During the past TWO (2) weeks, about how often did you have 4 or more drinks in a single day? [cite: 109, 111]"),
      Level2AdolescentQuestionnaireData("9", "SU3", "During the past TWO (2) weeks, about how often did you smoke a cigarette, a cigar, or pipe or use snuff or chewing tobacco? [cite: 109, 112]"),
      Level2AdolescentQuestionnaireData("9", "SU4", "During the past TWO (2) weeks, about how often did you use Painkillers (like Vicodin) ON YOUR OWN? [cite: 113, 116]"),
      Level2AdolescentQuestionnaireData("9", "SU5", "During the past TWO (2) weeks, about how often did you use Stimulants (like Ritalin, Adderall) ON YOUR OWN? [cite: 113, 117]"),
      Level2AdolescentQuestionnaireData("9", "SU6", "During the past TWO (2) weeks, about how often did you use Sedatives or tranquilizers (like sleeping pills or Valium) ON YOUR OWN? [cite: 113, 118]"),
      Level2AdolescentQuestionnaireData("9", "SU7", "During the past TWO (2) weeks, about how often did you use Steroids? [cite: 119, 120]"),
      Level2AdolescentQuestionnaireData("9", "SU8", "During the past TWO (2) weeks, about how often did you use Marijuana? [cite: 119, 122]"),
      Level2AdolescentQuestionnaireData("9", "SU9", "During the past TWO (2) weeks, about how often did you use Cocaine or crack? [cite: 119, 123]"),
      Level2AdolescentQuestionnaireData("9", "SU10", "During the past TWO (2) weeks, about how often did you use Club drugs (like ecstasy)? [cite: 119, 124]"),
      Level2AdolescentQuestionnaireData("9", "SU11", "During the past TWO (2) weeks, about how often did you use Hallucinogens (like LSD)? [cite: 119, 125]"),
      Level2AdolescentQuestionnaireData("9", "SU12", "During the past TWO (2) weeks, about how often did you use Heroin? [cite: 119, 126]"),
      Level2AdolescentQuestionnaireData("9", "SU13", "During the past TWO (2) weeks, about how often did you use Inhalants or solvents (like glue)? [cite: 119, 127]"),
      Level2AdolescentQuestionnaireData("9", "SU14", "During the past TWO (2) weeks, about how often did you use Methamphetamine (like speed)? [cite: 119, 128]"),
    ],
  };
}

// --- JOURNALING/SENTIMENT DATA STRUCTURES ---

class SentimentResult {
  final String emoji;
  final double score; // e.g., -1.0 (very negative) to 1.0 (very positive)
  final String description;

  const SentimentResult(this.emoji, this.score, this.description);
}

class JournalEntry {
  final DateTime date;
  final String text;
  final SentimentResult sentiment;

  JournalEntry({
    required this.date,
    required this.text,
    required this.sentiment,
  });
}

// --- MOCK SERVICE LAYER FOR JOURNALING/SENTIMENT ---

class MockSentimentService {
  SentimentResult analyze(String text) {
    if (text.isEmpty) {
      return const SentimentResult("⚪", 0.0, "No entry");
    }
    
    final isNegative = text.toLowerCase().contains('down') || text.toLowerCase().contains('overwhelming') || text.toLowerCase().contains('sad');
    final isPositive = text.toLowerCase().contains('happy') || text.toLowerCase().contains('great') || text.toLowerCase().contains('fun');

    if (isNegative) {
      return const SentimentResult("😞", -0.7, "Feeling low");
    } else if (isPositive) {
      return const SentimentResult("😊", 0.8, "Positive mood");
    }
    
    final randomScore = Random().nextDouble() * 2 - 1;
    if (randomScore > 0.6) return const SentimentResult("😄", 0.9, "Very happy");
    if (randomScore > 0.2) return const SentimentResult("🙂", 0.4, "Content");
    if (randomScore > -0.2) return const SentimentResult("😐", 0.0, "Neutral");
    if (randomScore > -0.6) return const SentimentResult("😟", -0.4, "A bit worried");
    return const SentimentResult("😢", -0.8, "Feeling sad");
  }

  JournalEntry? getEntry(DateTime date) {
    final mockEntries = _getMockData();
    try {
      return mockEntries.firstWhere(
          (e) => e.date.isSameDay(date));
    } catch (e) {
      return null;
    }
  }

  final List<JournalEntry> _persistedEntries = _getMockData(); 

  void saveEntry(JournalEntry entry) {
    _persistedEntries.removeWhere((e) => e.date.isSameDay(entry.date));
    _persistedEntries.add(entry);
    _persistedEntries.sort((a, b) => b.date.compareTo(a.date));
  }

  List<JournalEntry> getAllEntries() {
    return List.unmodifiable(_persistedEntries);
  }

  static List<JournalEntry> _getMockData() {
    return [
      JournalEntry(
          date: DateTime(2025, 10, 2),
          text: "I felt zero motivation. Stayed inside all day, the hours just melting into one another. The feeling of 'can't start' was overwhelming.",
          sentiment: const SentimentResult("😞", -0.7, "Feeling low")),
      JournalEntry(
          date: DateTime(2025, 10, 3),
          text: "Had a small win today by cleaning my room. Felt good to accomplish something. Happy to see the sun.",
          sentiment: const SentimentResult("😊", 0.8, "Positive mood")),
      JournalEntry(
          date: DateTime(2025, 10, 4),
          text: "Very neutral day. Just worked and watched TV. No strong feelings either way.",
          sentiment: const SentimentResult("😐", 0.0, "Neutral")),
      JournalEntry(
          date: DateTime(2025, 10, 7),
          text: "Anxiety was high today. Worried about an upcoming presentation.",
          sentiment: const SentimentResult("😟", -0.4, "A bit worried")),
      JournalEntry(
          date: DateTime(2025, 10, 13),
          text: "An important day. Met with a new professional.",
          sentiment: const SentimentResult("🙂", 0.4, "Content")),
    ];
  }
}

extension DateOnlyCompare on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

// --- CONSTANTS & STYLES ---

class AppColors {
  static const Color primary = Color(0xFF00C8C8); // Bright Cyan
  static const Color secondary = Color(0xFF007A7A); // Darker Teal
  static const Color background = Color(0xFFF7FFF7); // Off-White/Minty Background
  static const Color cardColor = Color(0xFFEEF7E8); // Light Green Card
  static const Color text = Color(0xFF2C3E50); // Dark text
  static const Color buttonShadow = Color(0xAA00C8C8);
  static const Color warning = Color(0xFFFF9800); // Amber for warnings/mild
  static const Color danger = Color(0xFFE53935); // Red for severe
}

const TextStyle kTitleStyle = TextStyle(
  color: AppColors.secondary,
  fontSize: 32,
  fontWeight: FontWeight.w900,
  letterSpacing: 1.5,
);

const TextStyle kSubtitleStyle = TextStyle(
  color: AppColors.primary,
  fontSize: 16,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.5,
);

// --- MAIN APP WIDGET ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MindGaugeApp());
}

class MindGaugeApp extends StatelessWidget {
  const MindGaugeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MindGauge',
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: MaterialColor(AppColors.primary.value, {
            50: AppColors.primary.withOpacity(0.1),
            100: AppColors.primary.withOpacity(0.2),
            200: AppColors.primary.withOpacity(0.3),
            300: AppColors.primary.withOpacity(0.4),
            400: AppColors.primary.withOpacity(0.5),
            500: AppColors.primary.withOpacity(0.6),
            600: AppColors.primary.withOpacity(0.7),
            700: AppColors.primary.withOpacity(0.8),
            800: AppColors.primary.withOpacity(0.9),
            900: AppColors.primary.withOpacity(1.0),
          }),
        ).copyWith(secondary: AppColors.secondary),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// --- WIDGETS ---

class StyledButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color shadowColor;

  const StyledButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = AppColors.primary,
    this.shadowColor = AppColors.buttonShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(25),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            elevation: 0,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String label;
  final bool isPassword;
  final TextEditingController? controller;
  final String? Function(String?)? validator; 
  final TextInputType? keyboardType;

  const CustomTextField({
    super.key,
    required this.label,
    this.isPassword = false,
    this.controller,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(color: AppColors.text),
            validator: validator,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.danger, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.danger, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SCREENS ---

// 1. SPLASH SCREEN
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'mind_gauge_logo.jpeg',
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.psychology_outlined,
                  size: 150,
                  color: AppColors.primary,
                );
              },
            ),
            const SizedBox(height: 30),
            const Text('MINDGAUGE', style: kTitleStyle),
            const SizedBox(height: 10),
            const Text('Measure your Mental Health Status', style: kSubtitleStyle),
          ],
        ),
      ),
    );
  }
}


// 2. AUTH SCREEN (REGISTER/LOGIN CHOICE)
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology_outlined, size: 100, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text('MINDGAUGE', style: kTitleStyle),
              const SizedBox(height: 5),
              const Text('Measure your Mental Health Status', style: kSubtitleStyle),
              const Spacer(),
              StyledButton(
                text: 'REGISTER',
                onPressed: () => _navigateToRegister(context),
              ),
              const SizedBox(height: 25),
              StyledButton(
                text: 'LOGIN',
                onPressed: () => _navigateToLogin(context),
                color: AppColors.secondary,
                shadowColor: AppColors.secondary.withOpacity(0.7),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. LOGIN SCREEN
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; });

    try {
      final user = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      setState(() { _isLoading = false; });

      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainDashboard(userProfile: user)),
        );
      } else {
          // This would catch a user who logged in via Firebase Auth but whose 
          // profile details (name, age) are missing from the mock database.
          ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Login failed: Profile data missing.')),
         );
      }
    } on String catch (errorCode) {
      setState(() { _isLoading = false; });
      String message = 'Login failed.';
      if (errorCode == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (errorCode == 'wrong-password') {
        message = 'Wrong password provided.';
      } else {
        message = 'Firebase Error: $errorCode';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
  
  // FIX: Added dispose method
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.secondary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: SingleChildScrollView(
          // FIX: Wrapped Column in Form for validation
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Center(
                  child: Icon(Icons.psychology_outlined, size: 80, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                const Center(child: Text('MINDGAUGE', style: kTitleStyle)),
                const SizedBox(height: 5),
                const Center(child: Text('Measure your Mental Health Status', style: kSubtitleStyle)),
                const SizedBox(height: 40),
                CustomTextField(
                  label: 'E-mail id',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required.';
                    }
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                      return 'Please enter a valid email address.';
                    }
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Password',
                  isPassword: true,
                  controller: _passwordController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required.';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 50),
                _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : Center(
                      child: StyledButton(
                        text: 'LOGIN',
                        onPressed: _handleLogin,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 4. REGISTER SCREEN
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return; 
    }

    setState(() { _isLoading = true; });

    final int? age = int.tryParse(_ageController.text);
    
    // Safety check for age (validation should handle this, but for try-catch clarity)
    if (age == null) {
       setState(() { _isLoading = false; });
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Registration failed: Invalid age provided.')),
           );
       }
       return;
    }

    try {
      final userProfile = await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text,
        age: age,
        location: _locationController.text,
      );

      setState(() { _isLoading = false; });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration successful! Welcome, ${userProfile.name}. Please log in.')),
        );
        Navigator.of(context).pop(); 
      }
    } on String catch (errorCode) {
      setState(() { _isLoading = false; });
      
      String message = 'Registration failed. Please try again.';
      if (errorCode == 'email-already-in-use') {
        message = 'The email address is already in use.';
      } else if (errorCode == 'weak-password') {
        message = 'The password must be at least 6 characters.';
      } else if (errorCode == 'invalid-email') {
        message = 'The email address is not valid.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: $e')));
      }
    }
  }

  // FIX: Added dispose method
  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.secondary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Text('MINDGAUGE', style: kTitleStyle)),
                const SizedBox(height: 30),
                CustomTextField(
                  label: 'E-mail id', 
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value!.isEmpty) return 'Email is required';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return 'Enter a valid email';
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Name', 
                  controller: _nameController,
                  validator: (value) => value!.isEmpty ? 'Name is required' : null,
                ),
                CustomTextField(
                  label: 'Age', 
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty) return 'Age is required';
                    if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Must be a valid age';
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Password', 
                  isPassword: true, 
                  controller: _passwordController,
                  validator: (value) => value!.length < 6 ? 'Password must be at least 6 chars' : null,
                ),
                CustomTextField(
                  label: 'Location', 
                  controller: _locationController,
                  validator: (value) => value!.isEmpty ? 'Location is required' : null,
                ),
                const SizedBox(height: 50),
                _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : Center(
                      child: StyledButton(
                        text: 'REGISTER',
                        onPressed: _handleRegister,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 5. MAIN DASHBOARD (Corrected to StatefulWidget to support calendar/journal)
class MainDashboard extends StatefulWidget {
  final UserProfile userProfile;
  const MainDashboard({super.key, required this.userProfile});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final MockSentimentService _sentimentService = MockSentimentService();
  DateTime _focusedDay = DateTime(2025, 10, 13);
  DateTime _selectedDay = DateTime(2025, 10, 13);
  List<JournalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    setState(() {
      _entries = _sentimentService.getAllEntries();
    });
  }
  
  void _openJournalingScreen(DateTime date) async {
    final entry = await Navigator.of(context).push<JournalEntry>(
      MaterialPageRoute(
        builder: (context) => JournalingScreen(
          date: date,
          initialEntry: _sentimentService.getEntry(date),
        ),
      ),
    );

    if (entry != null) {
      _sentimentService.saveEntry(entry);
      _loadEntries();
      setState(() {
        _selectedDay = entry.date;
        _focusedDay = entry.date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final JournalEntry? currentEntry = _sentimentService.getEntry(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MINDGAUGE'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        actions: const [
          CustomDrawerButton(), 
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // USER INFO CARD
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(top: 10, bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${widget.userProfile.name}!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  const SizedBox(height: 5),
                  Text('Age: ${widget.userProfile.age} | Location: ${widget.userProfile.location}', style: const TextStyle(fontSize: 14, color: AppColors.text)),
                ],
              ),
            ),
            
            // --- CALENDAR SECTION ---
            const Text(
              'CALENDAR',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            SentimentCalendar(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              journalEntries: _entries,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay; 
                });
              },
            ),

            // --- JOURNAL SNIPPET SECTION ---
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Journal',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_month, color: AppColors.secondary.withOpacity(0.7)), 
                  ],
                ),
                Text(
                  '${_selectedDay.day}/${_selectedDay.month}',
                  style: const TextStyle(fontSize: 16, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 10),
            JournalSnippetCard(
              entry: currentEntry,
              selectedDate: _selectedDay,
              onTap: () => _openJournalingScreen(_selectedDay),
            ),
            const SizedBox(height: 30),
            Center(
              child: StyledButton(
                text: 'Start Symptom Check-In',
                onPressed: () {
                  // Pass age from user profile
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => QuestionnaireScreen(userAge: widget.userProfile.age)),
                   );
                },
                color: AppColors.primary,
                shadowColor: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openJournalingScreen(DateTime.now()),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// 6. QUESTIONNAIRE WIDGET & SCREEN
class QuestionnaireItem extends StatefulWidget {
  final BaseQuestionnaireData data; 
  final int index;
  const QuestionnaireItem({super.key, required this.data, required this.index});

  @override
  State<QuestionnaireItem> createState() => _QuestionnaireItemState();
}

class _QuestionnaireItemState extends State<QuestionnaireItem> {
  int get sliderValue => widget.data.score.round();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.data.questionNumber}. ${widget.data.questionText}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.remove, color: AppColors.secondary),
              Expanded(
                child: Slider(
                  value: widget.data.score,
                  min: 0,
                  max: 4,
                  divisions: 4,
                  label: sliderValue.toString(),
                  onChanged: (double value) {
                    setState(() {
                      widget.data.score = value;
                    });
                  },
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.primary.withOpacity(0.3),
                ),
              ),
              Text(
                sliderValue.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.add, color: AppColors.secondary),
            ],
          ),
        ],
      ),
    );
  }
}

class QuestionnaireScreen extends StatefulWidget {
  // FIX: Re-introduced userAge parameter
  final int userAge;
  const QuestionnaireScreen({super.key, required this.userAge});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  // FIX: Use late initialization and MockService to fetch age-based questions
  late final List<QuestionnaireData> _questions;
  final MockQuestionnaireService _service = MockQuestionnaireService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // FIX: Get questions based on widget.userAge
    _questions = MockQuestionnaireService.getLevel1Questions(widget.userAge);
  }

  void _handleSubmit() async {
    setState(() {
      _isLoading = true;
    });

final List<DomainScore> results = await _service.submitQuestionnaire(_questions, widget.userAge);
    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => AssessmentResultScreen(results: results,userAge: widget.userAge,)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Level 1 Symptom Check-In'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menu tapped: Detected Issue, Trends, etc.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Questionnaire Version: ${MockQuestionnaireService.mapAgeToQuestionnaire(widget.userAge).toString().split('.').last}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Rate how much or how often you have been bothered by each problem during the past TWO (2) WEEKS.'),
                  SizedBox(height: 10),
                  Text('Response Scale:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text('0 - None/Not at all'),
                  Text('1 - Slight (Rare, less than a day or two)'),
                  Text('2 - Mild (Several days)'),
                  Text('3 - Moderate (More than half the days)'),
                  Text('4 - Severe (Nearly every day)'),
                ],
              ),
            ),
            ..._questions.asMap().entries.map((entry) =>
              QuestionnaireItem(data: entry.value, index: entry.key + 1)),
            const SizedBox(height: 40),
            Center(
              child: _isLoading
                ? const CircularProgressIndicator(color: AppColors.primary)
                : StyledButton(
                    text: 'SUBMIT ASSESSMENT',
                    onPressed: _handleSubmit,
                  ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}


// 7. ASSESSMENT RESULT SCREEN
class AssessmentResultScreen extends StatelessWidget {
  final List<DomainScore> results;
  final int userAge;
  const AssessmentResultScreen({super.key, required this.results,required this.userAge,});

  @override
  Widget build(BuildContext context) {
    final bool needsFollowUp = results.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Results'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              needsFollowUp 
                ? '⚠️ Further Assessment Recommended' 
                : '✅ Level 1 Check-In Complete',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: needsFollowUp ? AppColors.danger : AppColors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              needsFollowUp 
                ? 'Your responses indicate symptoms in the areas below that meet the threshold for clinical follow-up using a **Level 2 Cross-Cutting Symptom Measure**.'
                : 'Your responses did not meet the clinical threshold for requiring further Level 2 assessment at this time.',
              style: const TextStyle(fontSize: 16, color: AppColors.text),
            ),
            
            const Divider(height: 40, thickness: 1, color: AppColors.secondary),

            if (needsFollowUp) ...[
              const Text(
                'Take These Follow-Up Questionnaires:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
              const SizedBox(height: 15),
              ...results.map((score) => DomainResultCard(score: score,userAge: userAge,)).toList(),
            ] else 
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.sentiment_satisfied_alt, size: 80, color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text(
                      'All clear! Check in again when clinically indicated.',
                      style: kSubtitleStyle.copyWith(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    StyledButton(
                      text: 'Return to Dashboard',
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 8. WIDGET for Domain Result
class DomainResultCard extends StatelessWidget {
  final DomainScore score;
  final int userAge;
  const DomainResultCard({super.key, required this.score, required this.userAge});
  Color _getSeverityColor(int score) {
    if (score >= 3) return AppColors.danger;
    if (score == 2 || score == 1) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor(score.highestScore);
    final isLevel2Available = score.Level2AdultMeasure != 'None';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: severityColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: severityColor),
              const SizedBox(width: 8),
              Text(
                '${score.domainName} (${score.severity})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: severityColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '• ${score.domainName}: Highest Score ${score.highestScore} (Threshold >= ${score.thresholdScore})',
            style: const TextStyle(color: AppColors.text, fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (isLevel2Available) 
            StyledButton(
              text: 'TAKE ${score.domainName.toUpperCase()} LEVEL 2 MEASURE',
              onPressed: () {
                // Logic to route based on age
                final bool isAdolescent = MockQuestionnaireService.mapAgeToQuestionnaire(userAge) == QuestionnaireType.adolescentLevel1;
                
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => isAdolescent 
                        ? Level2AdolescentQuestionnaireScreen(domainScore: score)
                        : Level2AdultQuestionnaireScreen(domainScore: score),
                  ),
                );
              },
              color: AppColors.secondary,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No dedicated Level 2 measure is available for ${score.domainName}. Consult a clinician.',
                style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.text.withOpacity(0.7)),
              ),
            ),
        ],
      ),
    );
  }
}

// NEW SCREEN FOR Level2Adult QUESTIONNAIRE:
class Level2AdultQuestionnaireScreen extends StatefulWidget {
  final DomainScore domainScore;
  const Level2AdultQuestionnaireScreen({super.key, required this.domainScore});

  @override
  State<Level2AdultQuestionnaireScreen> createState() => _Level2AdultQuestionnaireScreenState();
}

class _Level2AdultQuestionnaireScreenState extends State<Level2AdultQuestionnaireScreen> {
  // Use an empty list as a default if the domain is not found
  late final List<Level2AdultQuestionnaireData> _questions; 
  
  @override
  void initState() {
    super.initState();
    // Correctly access the Level 2 questions map using the domainName string key
    _questions = MockQuestionnaireService._level2AdultQuestions[widget.domainScore.domainName] ?? []; 
    
    if (_questions.isEmpty) {
      // Show a message if no questions are found.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: No Level 2 questions found for ${widget.domainScore.domainName}.")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.domainScore.domainName} Level 2'), backgroundColor: AppColors.secondary),
        body: const Center(child: Text("Level 2 Questionnaire not available (Mock Data Error).")),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.domainScore.domainName} Level 2 Assessment'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Follow-up: ${widget.domainScore.Level2AdultMeasure}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            Text(
              'Your Level 1 score was ${widget.domainScore.highestScore} (${widget.domainScore.severity}). Please complete this focused Level 2 measure:',
              style: const TextStyle(fontSize: 16),
            ),
            const Divider(height: 30),

            // Display the Level 2 Questionnaire items using the shared widget
            ..._questions.asMap().entries.map((entry) =>
              QuestionnaireItem(data: entry.value, index: entry.key + 1)),
            
            const SizedBox(height: 40),
            Center(
              child: StyledButton(
                text: 'SUBMIT LEVEL 2 ASSESSMENT',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Level 2 Submission Mocked for ${widget.domainScore.domainName}.')),
                  );
                  Navigator.of(context).pop();
                },
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
class Level2AdolescentQuestionnaireScreen extends StatefulWidget {
  final DomainScore domainScore;
  const Level2AdolescentQuestionnaireScreen({super.key, required this.domainScore});

  @override
  State<Level2AdolescentQuestionnaireScreen> createState() => _Level2AdolescentQuestionnaireScreenState();
}

class _Level2AdolescentQuestionnaireScreenState extends State<Level2AdolescentQuestionnaireScreen> {
  late final List<Level2AdolescentQuestionnaireData> _questions; 
  
  @override
  void initState() {
    super.initState();
    // Access the Adolescent Level 2 map
    _questions = MockQuestionnaireService._level2AdolescentQuestions[widget.domainScore.domainName] ?? []; 
    
    if (_questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: No Adolescent Level 2 questions found for ${widget.domainScore.domainName}.")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.domainScore.domainName} Level 2'), backgroundColor: AppColors.secondary),
        body: const Center(child: Text("Child Level 2 Questionnaire not available.")),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.domainScore.domainName} (Age 11-17)'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focused Follow-up Measure ',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            const Text(
              'Based on your previous answers, please answer how much you have been bothered by these problems in the past 7 days. [cite: 5, 22, 33, 51, 60, 98]',
              style: TextStyle(fontSize: 16),
            ),
            const Divider(height: 30),
            ..._questions.asMap().entries.map((entry) =>
              QuestionnaireItem(data: entry.value, index: entry.key + 1)),
            const SizedBox(height: 40),
            Center(
              child: StyledButton(
                text: 'SUBMIT CHILD LEVEL 2',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Submission successful for child domain: ${widget.domainScore.domainName}.')),
                  );
                  Navigator.of(context).pop();
                },
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
// --- NEW WIDGETS FOR DASHBOARD ---

class SentimentCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<JournalEntry> journalEntries;
  final Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  const SentimentCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.journalEntries,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime(2025, 10, 1);
    final daysInMonth = 31;
    final firstDayOfWeek = 3; // October 1, 2025 is a Wednesday (1-Sun, 2-Mon, 3-Tue)

    const List<String> weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    final Map<int, String> emojiMap = {
      for (var entry in journalEntries.where((e) => e.date.month == focusedDay.month)) entry.date.day: entry.sentiment.emoji
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'October, ${focusedDay.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Row(
                  children: [
                    Icon(Icons.arrow_drop_up, color: AppColors.secondary, size: 24),
                    Icon(Icons.arrow_drop_down, color: AppColors.secondary, size: 24),
                  ],
                ),
              ],
            ),
          ),
          const Divider(thickness: 1, height: 10),
          
          // Weekday Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays
                .map((day) => Expanded(
                        child: Center(
                          child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        ),
                      ))
                .toList(),
          ),
          
          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4.0,
              crossAxisSpacing: 4.0,
            ),
            itemCount: daysInMonth + firstDayOfWeek,
            itemBuilder: (context, index) {
              if (index < firstDayOfWeek) {
                return Container();
              }

              final dayOfMonth = index - firstDayOfWeek + 1;
              final date = DateTime(focusedDay.year, focusedDay.month, dayOfMonth);
              final isSelected = date.isSameDay(selectedDay);
              final emoji = emojiMap[dayOfMonth] ?? '';
              
              return GestureDetector(
                onTap: () => onDaySelected(date, focusedDay),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isSelected ? AppColors.primary : Colors.transparent,
                      child: Text(
                        '$dayOfMonth',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.text,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (emoji.isNotEmpty)
                      SizedBox(
                        height: 14,
                        width: 25,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(emoji, style: const TextStyle(fontSize: 14)),
                        ),
                      ), 
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class JournalSnippetCard extends StatelessWidget {
  final JournalEntry? entry;
  final DateTime selectedDate;
  final VoidCallback onTap;

  const JournalSnippetCard({
    super.key,
    required this.entry,
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasEntry = entry != null;
    
    final String snippetText = hasEntry
        ? entry!.text
        : selectedDate.isSameDay(DateTime.now())
            ? 'Tap to write your thoughts for today.'
            : 'No journal entry for this date.';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(15),
          border: hasEntry ? Border.all(color: AppColors.secondary.withOpacity(0.3)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasEntry)
              Text(
                'Sentiment: ${entry!.sentiment.emoji} ${entry!.sentiment.description}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: entry!.sentiment.score < 0 ? AppColors.danger : AppColors.primary,
                ),
              ),
            if (hasEntry) const SizedBox(height: 8),
            Text(
              snippetText,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                color: hasEntry ? AppColors.text : AppColors.secondary.withOpacity(0.7),
                fontStyle: hasEntry ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW SCREEN FOR JOURNAL ENTRY ---

class JournalingScreen extends StatefulWidget {
  final DateTime date;
  final JournalEntry? initialEntry;

  const JournalingScreen({
    super.key,
    required this.date,
    this.initialEntry,
  });

  @override
  State<JournalingScreen> createState() => _JournalingScreenState();
}

class _JournalingScreenState extends State<JournalingScreen> {
  late final TextEditingController _controller;
  final MockSentimentService _sentimentService = MockSentimentService();
  SentimentResult _currentSentiment = const SentimentResult("⚪", 0.0, "Analyzing...");

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEntry?.text ?? '');
    if (widget.initialEntry != null) {
      _currentSentiment = widget.initialEntry!.sentiment;
    }  
  }

  void _saveJournal() {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry cannot be empty.')),
      );
      return;
    }

    final analyzedSentiment = _sentimentService.analyze(_controller.text.trim());

    final newEntry = JournalEntry(
      date: widget.date.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
      text: _controller.text.trim(),
      sentiment: analyzedSentiment,
    );

    Navigator.of(context).pop(newEntry);
  }
  
  // FIX: Added dispose method
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Journal for ${widget.date.day}/${widget.date.month}/${widget.date.year}'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    'Sentiment: ${_currentSentiment.emoji}',
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentSentiment.description,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextFormField(
                controller: _controller,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: "Write down your thoughts and feelings...",
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: StyledButton(
                text: 'Save Journal Entry',
                onPressed: _saveJournal,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// --- CUSTOM OVERLAY MENU WIDGET ---

class CustomDrawerButton extends StatefulWidget {
  const CustomDrawerButton({super.key});

  @override
  State<CustomDrawerButton> createState() => _CustomDrawerButtonState();
}

class _CustomDrawerButtonState extends State<CustomDrawerButton> {
  OverlayEntry? _overlayEntry;

  void _showOverlay(BuildContext context) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }

    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + button.size.height + 5,
        right: 15,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column( 
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DrawerButton(text: 'DETECTED ISSUE', color: AppColors.secondary, onTap: _hideOverlay),
                _DrawerButton(text: 'RISK TRENDS', color: AppColors.secondary.withOpacity(0.9), onTap: _hideOverlay),
                _DrawerButton(text: 'RECOMMENDATIONS', color: AppColors.secondary.withOpacity(0.8), onTap: _hideOverlay),
                _DrawerButton(text: 'PROFESSIONALS', color: AppColors.secondary.withOpacity(0.7), onTap: _hideOverlay),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu, color: AppColors.secondary),
      onPressed: () => _showOverlay(context),
    );
  }
}

class _DrawerButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _DrawerButton({required this.text, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onTap();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$text tapped!')));
      },
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }
}