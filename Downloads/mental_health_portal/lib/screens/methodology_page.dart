import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../widgets/common.dart';

class MethodologyPage extends StatelessWidget {
  const MethodologyPage({super.key});

  @override
  Widget build(BuildContext context) => const Shell(
        title: 'Patient Mental Wellbeing Scoring',
        children: [
          Notice(screeningNotice),
          Text(
            'Score calculation',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'For the previous two weeks: Not at all = 0; Several days = 1; More than half the days = 2; Nearly every day = 3.',
          ),
          Text(
            'P = p₁ + p₂ + … + p₉     Range 0–27\nG = g₁ + g₂ + … + g₇     Range 0–21',
            style: TextStyle(fontSize: 20),
          ),
          Text(
            'P measures depressive symptoms; G measures anxiety symptoms. Do not combine the totals. Missing answers are incomplete, not zero. Functional difficulty is recorded separately.',
          ),
          Text(
            'Severity bands',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'PHQ-9: 0–4 Minimal; 5–9 Mild; 10–14 Moderate; 15–19 Moderately severe; 20–27 Severe.\nGAD-7: 0–4 Minimal; 5–9 Mild; 10–14 Moderate; 15–21 Severe.',
          ),
          Text(
            'Worked calculation',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'P = 2 + 2 + 2 + 1 + 1 + 1 + 1 + 0 + 0 = 10\nG = 2 + 2 + 2 + 2 + 1 + 1 + 0 = 10\nBoth are moderate. With Q9 = 0 and no other concerns: counsellor review.',
          ),
          Text(
            'Illustrative cases',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'PHQ 2, GAD 1, Q9 0 → Resources and optional consultation\nPHQ 14, GAD 8, Q9 0 → Counsellor review\nPHQ 15, GAD 7, Q9 0 → Psychologist review\nPHQ 2, GAD 15, Q9 0 → Psychologist review\nPHQ 1, GAD 0, Q9 1 → Prompt safety assessment despite low total',
          ),
          Text(
            'Proposed referral rules',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            '1. Acute danger identified by professional assessment: emergency care pathway.\n2. Q9 > 0 or another safety concern: prompt trained professional assessment.\n3. Missing required answers: incomplete; do not assign routine severity.\n4. P ≥ 15 or G ≥ 15 or professional override: psychologist review.\n5. Otherwise P ≥ 5 or G ≥ 5: counsellor review.\n6. Otherwise: resources and optional consultation.',
          ),
          Notice(
            'These are proposed service rules requiring clinical approval. A positive Q9 response does not by itself establish imminent danger; a zero response does not rule out risk. Existing safety requests remain open until assessed. Professionals can refer or change disposition with a documented reason.',
          ),
          Text(
            'Care workflow',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'Patient → Consent and questionnaires → Server scoring → Professional review → Follow-up',
          ),
          Text(
            'Counsellor dashboard: routine and moderate cases, counselling notes, shared guidance, appointments and referrals to a psychologist.\nPsychologist dashboard: referred, high-severity and escalated cases; psychological assessment, care planning and professional account approvals.',
          ),
          Text(
            'Both professionals see assigned or shared cases. Patients see their own scores, guidance and appointments; private clinical notes are restricted.',
          ),
          Text(
            'Sources\nPHQ-9: https://www.hiv.uw.edu/page/mental-health-screening/phq-9\nGAD-7: Spitzer et al. 2006, doi:10.1001/archinte.166.10.1092\nNIMH Adult ASQ Toolkit: https://www.nimh.nih.gov/research/research-conducted-at-nimh/asq-toolkit-materials/adults-asq-toolkit',
          ),
        ],
      );
}
