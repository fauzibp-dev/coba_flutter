from pathlib import Path
from PIL import Image
from docx import Document
from docx.shared import Cm, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH
from reportlab.platypus import SimpleDocTemplate, Paragraph, Image as RLImage, Spacer, PageBreak
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.pagesizes import A4
import tempfile

root=Path(__file__).resolve().parents[1]
output=root/"artifacts"
output.mkdir(exist_ok=True)
entries=[
 ("startup-home.png","Beranda KKMP Kerten"),
 ("uat-u15-category-sembako.png","Navigasi kategori Sembako"),
 ("search-results-beras.png","Hasil pencarian beras"),
 ("uat-validation-empty-search.png","Validasi pencarian tidak ditemukan"),
 ("uat-u23-product-detail.png","Detail produk"),
 ("uat-cart-plus-attempt.png","Penambahan kuantitas keranjang"),
 ("uat-cart-plus-second-attempt.png","Kuantitas dan subtotal keranjang"),
 ("uat-transaction-checkout.png","Tampilan checkout"),
 ("uat-address-form-filled.png","Form alamat berisi data uji"),
 ("uat-address-save-attempt.png","Aksi simpan alamat uji"),
 ("uat-address-create-failed.png","Alamat tidak muncul setelah disimpan"),
 ("uat-invalid-voucher.png","Validasi voucher tidak sah"),
 ("uat-admin-product-create-form.png","Buat produk uji oleh Super Admin"),
 ("uat-admin-product-read.png","Membaca produk uji"),
 ("uat-admin-product-edit-form.png","Edit produk uji"),
 ("uat-admin-product-archive-attempt.png","Arsip produk uji"),
 ("uat-reg013-error-log-center.png","Error Log Center"),
 ("uat-reg013-error-log-after-test.png","Observasi Error Log Center"),
 ("uat-chat-open.png","Customer Pusat Bantuan")
]
doc=Document()
sec=doc.sections[0]
sec.page_width,sec.page_height=Cm(21),Cm(29.7)
sec.top_margin,sec.bottom_margin=Cm(2),Cm(1.8)
sec.left_margin,sec.right_margin=Cm(2.4),Cm(2)
doc.styles["Normal"].font.name="Times New Roman"
doc.styles["Normal"].font.size=Pt(11)
doc.add_heading("Lampiran Bukti Screenshot Maestro MCP Server",0)
doc.add_paragraph("KKMP Kerten | UTS Mobile Testing 2026/2027")
doc.add_paragraph("Bukti asli dari repository fauzibp-dev/coba_flutter, branch test/maestro-exploration-20261111. Bukti tidak diambil dari Maestro Studio. Screenshot menampilkan langkah dan temuan terdokumentasi, tidak otomatis berarti setiap kriteria UAT lulus.")
p=doc.add_paragraph("Ringkasan UAT historis: 14 PASS, 1 FAIL, 3 BLOCKED, 118 NOT RUN (136 kasus).")
p.runs[0].bold=True
pdf=SimpleDocTemplate(str(output/"Lampiran_Bukti_Maestro_MCP_Server_GitHub.pdf"),pagesize=A4,rightMargin=45,leftMargin=45,topMargin=42,bottomMargin=42)
sty=getSampleStyleSheet()
pages=[Paragraph("Lampiran Bukti Screenshot Maestro MCP Server — KKMP Kerten",sty["Title"]),Spacer(1,15),Paragraph("Bukti asli dari GitHub; status UAT: 14 PASS, 1 FAIL, 3 BLOCKED, 118 NOT RUN.",sty["Normal"]),Spacer(1,24)]
tmp=Path(tempfile.mkdtemp())
for i,(filename,title) in enumerate(entries,1):
    src=root/filename
    if not src.is_file():raise FileNotFoundError(src)
    with Image.open(src) as img:
        rgb=img.convert("RGB")
        rgb.thumbnail((950,1400))
        w,h=rgb.size
        jpg=tmp/("pic%02d.jpg"%i)
        rgb.save(jpg,"JPEG",quality=84,optimize=True)
    doc.add_heading("Gambar %d — %s"%(i,title),level=2)
    run=doc.add_paragraph().add_run()
    k=min(14.4*37.8/w,17.4*37.8/h)
    run.add_picture(str(jpg),width=Cm(w*k/37.8),height=Cm(h*k/37.8))
    doc.add_paragraph("Sumber file asli: "+filename)
    if i!=len(entries):doc.add_page_break()
    fac=min((A4[0]-95)/w,(A4[1]-142)/h)
    pages.append(Paragraph("Gambar %d — %s"%(i,title),sty["Heading2"]))
    pages.append(Spacer(1,12))
    pages.append(RLImage(str(jpg),width=w*fac,height=h*fac))
    pages.append(Spacer(1,8))
    pages.append(Paragraph("Sumber: "+filename,sty["Normal"]))
    if i!=len(entries):pages.append(PageBreak())
doc.save(output/"Lampiran_Bukti_Maestro_MCP_Server_GitHub.docx")
pdf.build(pages)
print("Created 19 real screenshot pages in PDF and DOCX.")
