using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

namespace snezzidebugger
{
    public partial class Form2 : Form
    {
        StringBuilder report = new StringBuilder();

        public Form2()
        {
            InitializeComponent();
        }

        public string[] left;
        public string[] right;
        public int leftIndex = 0, rightIndex = 0;
        public void readBegin()
        {
            left = textBox1.Text.Split('\n');
            right = textBox2.Text.Split('\n');
            leftIndex = 0;
            rightIndex = 0;


        }

        public string[] readString( int leftRight )
        {
            string[] x = new string[3];
            try
            {
                if (leftRight == 0)
                {
                    string s = left[leftIndex++];
                    while( s.Trim()=="" || s.Contains( "***" ) )
                        s = left[leftIndex++];

                    x[0] = s.Substring(0, 8);
                    x[1] = s.Substring(45, 52);
                    x[2] = s.Substring(21, 24); 
                    return x;
                }
                else
                {
                    string s = right[rightIndex++];
                    while (s.Trim() == "" || s.Contains("***"))
                        s = right[rightIndex++];

                    x[0] = s.Substring(0, 8);
                    x[1] = s.Substring(36, 52);
                    x[2] = "";
                    return x;
                }
            }
            catch
            {
                return null;
            }
        }

        private void button1_Click(object sender, EventArgs e)
        {
            report = new StringBuilder();
            string pl = "", pr = "";

            readBegin();
            while (true)
            {
                string[] sl = readString(0);

                if (sl == null)
                    break;

                while (sl[0] == pl)
                {
                    sl = readString(0);
                    if (sl == null)
                        break;
                }
                if (sl == null)
                    break;
                pl = sl[0];
                
                string[] sr = readString(1);
                if (sr == null)
                    break;
                while (sr[0] == pr)
                {
                    sr = readString(1);
                    if (sr == null)
                        break;
                }
                if (sr == null)
                    break;
                pr = sr[0];

                if (sl[0] != sr[0])
                {

                    report.Append(sl[0] + "**" + sr[0]);
                }
                else
                    report.Append(sl[0] + " " + "        ");

                report.Append( " | " + sl[2] );

                string[] rl = sl[1].Split(' ');
                string[] rr = sr[1].Split(' ');
                for (int i = 0; i < rl.Length; i++)
                {
                    if (rl[i] != rr[i])
                    {
                        if (rl[i].StartsWith("S:"))
                            report.Append("(" + rl[i] + "*%" + rr[i] + ") ");
                        else
                            report.Append("(" + rl[i] + "**" + rr[i] + ") ");
                    }
                    else
                        report.Append(rl[i] + " ");
                }
                report.Append("\r\n");
            }

            button3.Visible = true;
            textBox3.Visible = true;
            button4.Visible = true;
            textBox3.Text = report.ToString();
        }

        private void textBox1_TextChanged(object sender, EventArgs e)
        {
            
        }

        private void button2_Click(object sender, EventArgs e)
        {
            Hide();
        }

        private void button3_Click(object sender, EventArgs e)
        {
            button3.Visible = false;
            textBox3.Visible = false;
            button4.Visible = false;
        }

        private void button4_Click(object sender, EventArgs e)
        {
            int i = textBox3.Text.IndexOf( "*", textBox3.SelectionStart+1 );
            if (i != -1)
            {
                textBox3.Focus();
                textBox3.Select(i, 1);
                textBox3.ScrollToCaret();
            }
        }

        private void button5_Click(object sender, EventArgs e)
        {
            int i = textBox3.Text.IndexOf("**", textBox3.SelectionStart + 1);
            if (i != -1)
            {
                textBox3.Focus();
                textBox3.Select(i, 1);
                textBox3.ScrollToCaret();
            }
        }
    }
}

