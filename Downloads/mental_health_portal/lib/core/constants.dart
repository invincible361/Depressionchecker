import 'package:flutter/material.dart';

const brand = Color(0xFF176B61);
const supportText =
    'If you may hurt yourself or are in immediate danger, seek emergency help now or contact a trusted person. '
    'Do not wait for an app response. This service is not monitored continuously. A saved alert is a request for professional review, not an emergency dispatch.';
const screeningNotice =
    'For college students aged 18–25. PHQ-9 and GAD-7 screen symptoms over the previous two weeks. '
    'Scores support assessment; a qualified professional makes the diagnosis.';

String pathwayLabel(String value) => switch (value) {
  'counsellor' => 'Counsellor review',
  'psychologist' => 'Psychologist review',
  'safety' => 'Prompt safety assessment',
  'emergency' => 'Emergency care pathway',
  'incomplete' => 'Incomplete questionnaire',
  _ => 'Resources and optional consultation',
};

