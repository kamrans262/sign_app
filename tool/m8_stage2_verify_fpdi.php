<?php

declare(strict_types=1);

/**
 * CI-only compatibility verifier: imports the exact synthetic PDF produced by
 * Sign2DigitalQuotePdfBuilder (Flutter/Dart) through the same FPDF/FPDI versions
 * locked by the Laravel backend. It never touches actual customer documents.
 */
$vendor = getenv('M8_FPDI_VENDOR');
if (!is_string($vendor) || !is_file($vendor.'/autoload.php')) {
    fwrite(STDERR, "FPDI test dependencies are unavailable.\n");
    exit(2);
}
require $vendor.'/autoload.php';

$path = $argv[1] ?? '';
if (!$path || !is_file($path)) {
    fwrite(STDERR, "Missing real Flutter-generated synthetic quote fixture.\n");
    exit(2);
}
$original = file_get_contents($path);
if (!is_string($original) || strlen($original) < 1000 ||
    !str_starts_with($original, '%PDF-1.4') ||
    !str_contains(substr($original, -4096), '%%EOF')) {
    fwrite(STDERR, "Flutter approved PDF failed pre-import format verification.\n");
    exit(3);
}
$originalHash = hash('sha256', $original);
$writer = new \setasign\Fpdi\Fpdi();
try {
    $pageCount = $writer->setSourceFile(
        \setasign\Fpdi\PdfParser\StreamReader::createByString($original)
    );
    if ($pageCount < 1 || $pageCount > 100) {
        throw new RuntimeException('Unexpected source page count');
    }
    for ($i = 1; $i <= $pageCount; $i++) {
        $page = $writer->importPage($i);
        $size = $writer->getTemplateSize($page);
        $writer->AddPage($size['orientation'], [$size['width'], $size['height']]);
        $writer->useTemplate($page, 0, 0, $size['width'], $size['height'], true);
    }
    $writer->AddPage('P', 'A4');
    $writer->SetFont('Helvetica', '', 10);
    $writer->Cell(120, 10, 'Synthetic signed document evidence page');
    $result = $writer->Output('S');
    if (!is_string($result) || !str_starts_with($result, '%PDF-') ||
        !str_contains(substr($result, -4096), '%%EOF')) {
        throw new RuntimeException('FPDI output is not a finalized PDF');
    }
    if (!hash_equals($originalHash, hash('sha256', file_get_contents($path)))) {
        throw new RuntimeException('The approval-frozen source bytes changed');
    }
    echo "FPDI_COMPAT_PASS: Flutter PDF 1.4 imported, ".$pageCount.
        " source page(s), appended one evidence page. Approved SHA=".$originalHash."\n";
} catch (Throwable $error) {
    fwrite(STDERR, "FPDI_COMPAT_FAIL: ".$error->getMessage()."\n");
    exit(1);
}
