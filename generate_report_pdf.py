import os
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    """Canvas that prints exact predetermined page numbers matching the diary (7, 8, 9, 10)."""
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        page_numbers = [7, 8, 9, 10]
        for i, state in enumerate(self._saved_page_states):
            self.__dict__.update(state)
            pg_num = page_numbers[i] if i < len(page_numbers) else i + 7
            self.setFont("Helvetica", 10)
            self.drawCentredString(A4[0] / 2.0, 20, str(pg_num))
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

def build_pdf(filename):
    doc = SimpleDocTemplate(
        filename,
        pagesize=A4,
        leftMargin=32,
        rightMargin=32,
        topMargin=26,
        bottomMargin=36
    )

    styles = getSampleStyleSheet()

    # Custom styles
    title_style = ParagraphStyle(
        'ReviewTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=16,
        alignment=1, # Center
    )

    weekly_title_style = ParagraphStyle(
        'WeeklyTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=14,
        alignment=1, # Center
    )

    date_style = ParagraphStyle(
        'DateStyle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=13,
        alignment=2, # Right
    )

    box_header_style = ParagraphStyle(
        'BoxHeader',
        parent=styles['Normal'],
        fontName='Helvetica-BoldOblique',
        fontSize=9,
        leading=12,
        textColor=colors.black,
    )

    box_text_style = ParagraphStyle(
        'BoxText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=colors.HexColor('#111111'),
    )

    guide_text_style = ParagraphStyle(
        'GuideText',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=8.5,
        leading=12,
        textColor=colors.HexColor('#222222'),
    )

    table_header_style = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        alignment=1, # Center
    )

    meta_line_style = ParagraphStyle(
        'MetaLine',
        parent=styles['Normal'],
        fontName='Helvetica-BoldOblique',
        fontSize=9,
        leading=12,
    )

    story = []

    total_width = A4[0] - 64  # 595.27 - 64 = 531.27 pt
    col3_width = total_width / 3.0

    # -------------------------------------------------------------
    # PAGE 1 (DIARY PAGE 7): 2nd REVIEW REPORT
    # -------------------------------------------------------------
    p7_header = [
        [
            Paragraph("<u>2<sup>nd</sup> REVIEW REPORT</u>", title_style),
            Paragraph("<b>Date :</b> 17/08/2026", date_style)
        ]
    ]
    t_p7_head = Table(p7_header, colWidths=[total_width - 150, 150])
    t_p7_head.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 0),
    ]))

    p7_rows = [
        # Box 1
        [Paragraph("Response to the remarks of the 1<sup>st</sup> review:", box_header_style)],
        [Paragraph(
            "As recommended in the first review, we transitioned from preliminary conceptual models toward a dedicated mobile architecture with a structured behavioral data pipeline. "
            "We addressed feedback regarding habit estimation by planning a transition away from initial hard-coded if-else logic toward formal feature extraction and machine learning classification.",
            box_text_style
        )],
        # Box 2
        [Paragraph("Work done till the 1<sup>st</sup> review:", box_header_style)],
        [Paragraph(
            "Completed the comprehensive literature survey on mHealth smoking cessation tools and defined system requirements for edge-based gesture detection. "
            "Designed the core application UI wireframes in Flutter, created the initial Supabase database schema, and established baseline manual puff logging. "
            "Implemented initial hard-coded if-else logic based on historical puff counts to verify basic tracking functionality.",
            box_text_style
        )],
        # Box 3
        [Paragraph("Work done after the 1<sup>st</sup> review:", box_header_style)],
        [Paragraph(
            "Set up the cross-platform Flutter project architecture, implemented Supabase authentication, and created data models for puff events and sessions. "
            "Formulated dataset collection strategies for hand-to-mouth vape and cigarette gestures for YOLOv9 training. "
            "Designed the initial pipeline to log temporal behavioral metadata, such as inter-puff intervals and daily session clustering.",
            box_text_style
        )],
        # Box 4
        [Paragraph("Work to be done before 3<sup>rd</sup> review:", box_header_style)],
        [Paragraph(
            "Train and quantize the YOLOv9-tiny object detection model for on-device inference using TensorFlow Lite. "
            "Replace heuristic rules with a Decision Tree model for addiction risk classification and linear regression for craving prediction. "
            "Integrate live camera feeds via Dart Isolates and develop comprehensive dashboard visualization and craving relief modules.",
            box_text_style
        )],
        # Box 5
        [Paragraph("Remarks of the Guide:", box_header_style)],
        [Paragraph(
            "Architectural design and database schemas are well structured. Proceed with dataset collection and machine learning pipeline implementation as planned.",
            guide_text_style
        )],
    ]

    t_p7_main = Table(p7_rows, colWidths=[total_width])
    t_p7_main.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#999999')),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#F5F5F5')),
        ('BACKGROUND', (0,2), (-1,2), colors.HexColor('#F5F5F5')),
        ('BACKGROUND', (0,4), (-1,4), colors.HexColor('#F5F5F5')),
        ('BACKGROUND', (0,6), (-1,6), colors.HexColor('#F5F5F5')),
        ('BACKGROUND', (0,8), (-1,8), colors.HexColor('#F5F5F5')),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))

    # Date of Completion
    p7_prob = [
        [Paragraph("<b><i>Probable Date of Completion of Project Work:</i></b>  <u>25/11/2026</u>", meta_line_style)]
    ]
    t_p7_prob = Table(p7_prob, colWidths=[total_width])
    t_p7_prob.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
    ]))

    # Signatures
    p7_sig = [
        [
            Paragraph("Signature of the students", table_header_style),
            Paragraph("Signature of the Guide", table_header_style),
            Paragraph("Signature of Project Coordinator", table_header_style)
        ],
        ["\n\n", "\n\n", "\n\n"]
    ]
    t_p7_sig = Table(p7_sig, colWidths=[col3_width, col3_width, col3_width], rowHeights=[20, 36])
    t_p7_sig.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.black),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EFEFEF')),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
    ]))

    # Review Remarks
    p7_rev = [
        [Paragraph("Review Remarks:", box_header_style)],
        [Paragraph(
            "Good progress on mobile framework setup and database schema; ensure ML pipeline replaces rule-based heuristics before next review.",
            guide_text_style
        )]
    ]
    t_p7_rev = Table(p7_rev, colWidths=[total_width])
    t_p7_rev.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#999999')),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#F5F5F5')),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))

    # Committee
    p7_comm = [
        [Paragraph("Name & Signature of Review Committee Members", table_header_style), "", ""],
        ["\n\n", "\n\n", "\n\n"]
    ]
    t_p7_comm = Table(p7_comm, colWidths=[col3_width, col3_width, col3_width], rowHeights=[20, 34])
    t_p7_comm.setStyle(TableStyle([
        ('SPAN', (0,0), (2,0)),
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.black),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EFEFEF')),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
    ]))

    story.append(t_p7_head)
    story.append(Spacer(1, 4))
    story.append(t_p7_main)
    story.append(Spacer(1, 4))
    story.append(t_p7_prob)
    story.append(Spacer(1, 4))
    story.append(t_p7_sig)
    story.append(Spacer(1, 4))
    story.append(t_p7_rev)
    story.append(Spacer(1, 4))
    story.append(t_p7_comm)

    # -------------------------------------------------------------
    # PAGE 2 (DIARY PAGE 8): WEEKLY REPORTS
    # -------------------------------------------------------------
    story.append(PageBreak())

    def make_weekly_box(title_dates, report_date, work_done_text, guide_remarks_text):
        h_table = Table([
            [
                Paragraph(f"<u>Weekly Report ( {title_dates} )</u>", weekly_title_style),
                Paragraph(f"<b>Date :</b> {report_date}", date_style)
            ]
        ], colWidths=[total_width - 140, 140])
        h_table.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('BOTTOMPADDING', (0,0), (-1,-1), 3),
            ('TOPPADDING', (0,0), (-1,-1), 0),
        ]))

        b_rows = [
            [Paragraph("Work done in the Previous Week:", box_header_style)],
            [Paragraph(work_done_text, box_text_style)],
            [Paragraph("Remarks of the Guide:", box_header_style)],
            [Paragraph(guide_remarks_text, guide_text_style)],
        ]
        b_table = Table(b_rows, colWidths=[total_width])
        b_table.setStyle(TableStyle([
            ('BOX', (0,0), (-1,-1), 1.0, colors.black),
            ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#999999')),
            ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#F5F5F5')),
            ('BACKGROUND', (0,2), (-1,2), colors.HexColor('#F5F5F5')),
            ('TOPPADDING', (0,0), (-1,-1), 5),
            ('BOTTOMPADDING', (0,0), (-1,-1), 5),
            ('LEFTPADDING', (0,0), (-1,-1), 6),
            ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ]))

        s_rows = [
            [
                Paragraph("Signature of the students", table_header_style),
                Paragraph("Signature of the Guide", table_header_style),
                Paragraph("Signature of Project Coordinator", table_header_style)
            ],
            ["\n\n\n", "\n\n\n", "\n\n\n"]
        ]
        s_table = Table(s_rows, colWidths=[col3_width, col3_width, col3_width], rowHeights=[20, 42])
        s_table.setStyle(TableStyle([
            ('BOX', (0,0), (-1,-1), 1.0, colors.black),
            ('INNERGRID', (0,0), (-1,-1), 0.5, colors.black),
            ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EFEFEF')),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('ALIGN', (0,0), (-1,-1), 'CENTER'),
        ]))

        return [h_table, Spacer(1, 3), b_table, Spacer(1, 3), s_table]

    # Weekly Report 1 (Page 8 Top)
    for el in make_weekly_box(
        "24/08/2026 to 28/08/2026",
        "28/08/2026",
        "Completed approximately 40% of the behavioral metadata extraction and addiction classification pipeline. "
        "Conducted initial work on the Decision Tree based severity classification by defining key feature metrics, including daily puff frequency and inter-puff intervals. "
        "Prepared and structured the annotated video dataset to train the computer vision gesture recognition model.",
        "Good progress on behavioral feature extraction. Ensure the feature thresholds for the Decision Tree align with clinical addiction severity criteria."
    ):
        story.append(el)

    story.append(Spacer(1, 16))

    # Weekly Report 2 (Page 8 Bottom)
    for el in make_weekly_box(
        "31/08/2026 to 04/09/2026",
        "04/09/2026",
        "Trained the YOLOv9-tiny model on hand-to-mouth gestures and exported the quantized TFLite weights for mobile deployment. "
        "Integrated the TFLite inference engine into Flutter using background Dart Isolates to maintain a smooth 60 FPS camera preview. "
        "Implemented spatial mouth proximity boundaries and a 1.2-second dwell state machine to filter false-positive detections.",
        "Real-time inference integration using Isolates is commendable. Test edge detection under diverse ambient lighting conditions."
    ):
        story.append(el)

    # -------------------------------------------------------------
    # PAGE 3 (DIARY PAGE 9): WEEKLY REPORTS
    # -------------------------------------------------------------
    story.append(PageBreak())

    # Weekly Report 3 (Page 9 Top)
    for el in make_weekly_box(
        "07/09/26 to 25/09/26",
        "25/09/2026",
        "Finalized the Decision Tree addiction classifier to categorize users into Low, Moderate, and High severity tiers based on multi-day usage density. "
        "Developed the Multivariate Linear Regression model to forecast upcoming craving windows from historical session intervals. "
        "Integrated local background push notifications to proactively alert users before forecasted craving peaks.",
        "The integration of the predictive craving engine with local notifications is satisfactory. Proceed to user interface and analytics dashboard integration."
    ):
        story.append(el)

    story.append(Spacer(1, 16))

    # Weekly Report 4 (Page 9 Bottom)
    for el in make_weekly_box(
        "05/10/26 to 09/10/26",
        "09/10/2026",
        "Implemented interactive data visualization charts using fl_chart to display daily/weekly puff frequencies and session intervals. "
        "Developed craving relief utilities, including an animated 4-7-8 diaphragmatic breathing timer and behavioral urge distraction techniques. "
        "Conducted unit and widget testing across Supabase sync, video analysis, and ML feature calculation modules.",
        "Dashboard visualization and craving relief tools are nicely built. Prepare the consolidated system demonstration for the upcoming 3rd review."
    ):
        story.append(el)

    # -------------------------------------------------------------
    # PAGE 4 (DIARY PAGE 10): 3rd REVIEW REPORT
    # -------------------------------------------------------------
    story.append(PageBreak())

    p10_header = [
        [
            Paragraph("<u>3<sup>rd</sup> REVIEW REPORT</u>", title_style),
            Paragraph("<b>Date :</b> 31/10/26", date_style)
        ]
    ]
    t_p10_head = Table(p10_header, colWidths=[total_width - 150, 150])
    t_p10_head.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 0),
    ]))

    p10_rows = [
        # Box 1
        [Paragraph("Response to the remarks of the 2<sup>nd</sup> review:", box_header_style)],
        [Paragraph(
            "Fully eliminated legacy hard-coded heuristic logic by deploying trained ML models for addiction classification and craving forecasting. "
            "Successfully optimized on-device inference speed by isolating camera frame tensor preprocessing, maintaining 60 FPS UI rendering without dropped frames.",
            box_text_style
        )],
        # Box 2
        [Paragraph("Work done till the 2<sup>nd</sup> review:", box_header_style)],
        [Paragraph(
            "Completed system requirements, UI design, Supabase database integration, and foundational puff tracking workflows. "
            "Prepared the custom gesture dataset and framed the algorithmic structure for behavioral metadata extraction.",
            box_text_style
        )],
        # Box 3
        [Paragraph("Work done after the 2<sup>nd</sup> review:", box_header_style)],
        [Paragraph(
            "Trained, converted, and integrated the YOLOv9-tiny TFLite model with spatial and temporal dwell-time filtering for real-time puff detection. "
            "Implemented the Decision Tree severity classifier and linear regression craving predictor operating entirely on client-side behavioral metadata. "
            "Built comprehensive analytics dashboards, automated push alerts, and animated 4-7-8 breathing relief tools.",
            box_text_style
        )],
        # Box 4
        [Paragraph("Work to be done:", box_header_style)],
        [Paragraph(
            "Perform comprehensive field testing and latency benchmarking across different Android hardware specifications. "
            "Gather qualitative usability feedback on craving intervention effectiveness and finalize project documentation and the final report.",
            box_text_style
        )],
        # Box 5
        [Paragraph("Remarks of the Guide:", box_header_style)],
        [Paragraph(
            "All primary modules—edge vision detection, ML analytics, and user intervention—are functional and well integrated. Approved to proceed toward final report submission.",
            guide_text_style
        )],
    ]

    t_p10_main = Table(p10_rows, colWidths=[total_width])
    t_p10_main.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#999999')),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#F5F5F5')),
        ('BACKGROUND', (0,2), (-1,2), colors.HexColor('#F5F5F5')),
        ('BACKGROUND', (0,4), (-1,4), colors.HexColor('#F5F5F5')),
        ('BACKGROUND', (0,6), (-1,6), colors.HexColor('#F5F5F5')),
        ('BACKGROUND', (0,8), (-1,8), colors.HexColor('#F5F5F5')),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))

    # Date of Completion
    p10_prob = [
        [Paragraph("<b><i>Probable Date of Completion of Project Work:</i></b>  <u>25/11/2026</u>", meta_line_style)]
    ]
    t_p10_prob = Table(p10_prob, colWidths=[total_width])
    t_p10_prob.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
    ]))

    # Signatures
    p10_sig = [
        [
            Paragraph("Signature of the students", table_header_style),
            Paragraph("Signature of the Guide", table_header_style),
            Paragraph("Signature of Project Coordinator", table_header_style)
        ],
        ["\n\n", "\n\n", "\n\n"]
    ]
    t_p10_sig = Table(p10_sig, colWidths=[col3_width, col3_width, col3_width], rowHeights=[20, 36])
    t_p10_sig.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.black),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EFEFEF')),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
    ]))

    # Review Remarks
    p10_rev = [
        [Paragraph("Review Remarks:", box_header_style)],
        [Paragraph(
            "End-to-end working system demonstrated successfully. Proceed with final user evaluation and complete thesis documentation.",
            guide_text_style
        )]
    ]
    t_p10_rev = Table(p10_rev, colWidths=[total_width])
    t_p10_rev.setStyle(TableStyle([
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.HexColor('#999999')),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#F5F5F5')),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))

    # Committee
    p10_comm = [
        [Paragraph("Name & Signature of Review Committee Members", table_header_style), "", ""],
        ["\n\n", "\n\n", "\n\n"]
    ]
    t_p10_comm = Table(p10_comm, colWidths=[col3_width, col3_width, col3_width], rowHeights=[20, 34])
    t_p10_comm.setStyle(TableStyle([
        ('SPAN', (0,0), (2,0)),
        ('BOX', (0,0), (-1,-1), 1.0, colors.black),
        ('INNERGRID', (0,0), (-1,-1), 0.5, colors.black),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#EFEFEF')),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ALIGN', (0,0), (-1,-1), 'CENTER'),
    ]))

    story.append(t_p10_head)
    story.append(Spacer(1, 4))
    story.append(t_p10_main)
    story.append(Spacer(1, 4))
    story.append(t_p10_prob)
    story.append(Spacer(1, 4))
    story.append(t_p10_sig)
    story.append(Spacer(1, 4))
    story.append(t_p10_rev)
    story.append(Spacer(1, 4))
    story.append(t_p10_comm)

    # Build with NumberedCanvas
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Successfully generated {filename}")

if __name__ == '__main__':
    out_pdf = "Project_Review_and_Weekly_Reports.pdf"
    build_pdf(out_pdf)
