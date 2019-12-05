import UIKit
import PencilKit
import RxSwift
import RxCocoa

class CanvasPrototypeViewController: UIViewController, PKToolPickerObserver, PKCanvasViewDelegate {

    @IBOutlet weak private var closeButton: UIButton!
    @IBOutlet weak private var prevButton: TapAreaExpandButton!
    @IBOutlet weak private var pageNumLabel: UILabel!
    @IBOutlet weak private var nextButton: TapAreaExpandButton!
    @IBOutlet weak private var addPageButton: UIButton!
    @IBOutlet weak private var canvasView: PKCanvasView!
    private(set) var templateImageView: UIImageView?

    var maxPageNum: Int {
        pageDraws.count
    }
    var currentPageIndex: Int = 0 {
        didSet {
            updateUI()
        }
    }
    var pageDraws: [Draw] = []
    var canvasViewBackgroundColor: UIColor = .clear {
        didSet {
            if pageDraws[currentPageIndex].thumbnailImage != nil {
                canvasView.backgroundColor = UIColor.clear
            } else {
                canvasView.backgroundColor = self.canvasViewBackgroundColor
            }
        }
    }
    var isEnabledScoll: Bool = false {
        didSet {
            canvasView.isScrollEnabled = self.isEnabledScoll
        }
    }
    var isEnabledCanvasEdit: Bool = true

    private var disposeBag = DisposeBag()

    // MARK: - Lifecycle

    class func instantiate(draws: [Draw]) -> CanvasPrototypeViewController {
        let controller = UIStoryboard(name: "Canvas", bundle: .main).instantiateInitialViewController() as! CanvasPrototypeViewController
        controller.pageDraws = draws
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        canvasView.delegate = self
        initUI()
        bind()
        updateUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        templateImageView?.frame = canvasView.bounds
        canvasView.contentSize = canvasView.bounds.size
    }

    private func initUI() {
        if let firstDrawing = pageDraws.first {
            canvasViewBackgroundColor = firstDrawing.backgroundColor
            templateImageView?.image = firstDrawing.thumbnailImage
        }
        if let firstDrawingData = pageDraws.first?.drawingData, let firstDrawing = try? PKDrawing(data: firstDrawingData) {
            canvasView.drawing = firstDrawing
        }

        templateImageView = UIImageView()
        templateImageView?.clipsToBounds = true
        templateImageView?.contentMode = .scaleAspectFill
        if let defaultThumbnailImageView = templateImageView {
            canvasView.addSubview(defaultThumbnailImageView)
            canvasView.sendSubviewToBack(defaultThumbnailImageView)
        }
        canvasView.allowsFingerDrawing = true
    }

    private func bind() {
        closeButton.rx.tap.asDriver().throttle(.seconds(1), latest: false).drive(onNext: { [weak self] in
            self?.saveCurrentPage()
            self?.dismiss(animated: true, completion: nil)
        }).disposed(by: disposeBag)

        prevButton.rx.tap.asDriver().drive(onNext: { [weak self] in
            self?.prevDrawing()
        }).disposed(by: disposeBag)

        nextButton.rx.tap.asDriver().drive(onNext: { [weak self] in
            self?.nextDrawing()
        }).disposed(by: disposeBag)

        addPageButton.rx.tap.asDriver().drive(onNext: { [weak self] in
            let draw = Draw()
            draw.thumbnailImage = UIImage(named: "thumbnail")
//            draw.backgroundColor = .red
            self?.appendPage(draw)
        }).disposed(by: disposeBag)

    }

    private func updateCanvas() {
        if isEnabledCanvasEdit {
            enableEditCanvas()
        } else {
            disableEditCanvas()
        }
    }

    private func enableEditCanvas() {
        canvasView.drawingGestureRecognizer.isEnabled = true // ペンでかけるようにする

        if let window = UIApplication.shared.windows.first, let toolPicker = PKToolPicker.shared(for: window) {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            toolPicker.addObserver(self)
            canvasView.becomeFirstResponder()
        }
    }

    private func disableEditCanvas() {
        canvasView.drawingGestureRecognizer.isEnabled = false // ペンでかけないようにする

        if let window = UIApplication.shared.windows.first, let toolPicker = PKToolPicker.shared(for: window) {
            toolPicker.setVisible(false, forFirstResponder: canvasView)
            toolPicker.removeObserver(canvasView)
            toolPicker.removeObserver(self)
        }
    }

    private func appendPage(_ draw: Draw) {
        saveCurrentPage()
        pageDraws.append(draw)
        changePage(at: pageDraws.endIndex - 1)
    }

    private func saveCurrentPage() {
        pageDraws[currentPageIndex].drawingData = canvasView.drawing.dataRepresentation()

        delay(0.3) { [weak self] in
            guard let `self` = self else { return }

            if let templateImage = self.pageDraws[self.currentPageIndex].thumbnailImage {
                // PKCanvasView上のレンダリング情報とテンプレート画像を合成して一枚絵にする。
                // キャンバスのスクロールが有効の場合にはScrollView全域を対象とするためにContenSizeを使用する
                let contentSize = self.canvasView.contentSize
                let contentRect = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
                let drawImage = templateImage.composite(image: self.canvasView.drawing.image(from: contentRect, scale: 1.0))

                self.pageDraws[self.currentPageIndex].imageData = drawImage.jpegData(compressionQuality: 0.7)
                UIImageWriteToSavedPhotosAlbum(drawImage, self, #selector(self.didFinishSavingImage(_:didFinishSavingWithError:contextInfo:)), nil)
            } else {
                let drawImage = self.canvasView.getImage()
                self.pageDraws[self.currentPageIndex].imageData = drawImage.jpegData(compressionQuality: 0.7)
                UIImageWriteToSavedPhotosAlbum(drawImage, self, #selector(self.didFinishSavingImage(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }

    @objc func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: NSError!, contextInfo: UnsafeMutableRawPointer) {
        print("didFinishSavingImage")
    }

    private func changePage(at index: Int) {
        templateImageView?.image = pageDraws[index].thumbnailImage

        if let drawingData = pageDraws[index].drawingData, let drawing = try? PKDrawing(data: drawingData) {
            canvasView.drawing = drawing
        } else {
            canvasView.drawing = PKDrawing()
        }
        currentPageIndex = index
    }

    // MARK: Page Control

    private func prevDrawing() {
        saveCurrentPage()

        if currentPageIndex > 0 {
            currentPageIndex -= 1
            if let prevDrawingData = pageDraws[currentPageIndex].drawingData, let prevDrawing = try? PKDrawing(data: prevDrawingData) {
                canvasView.drawing = prevDrawing
            }
        }
        updateUI()
    }

    private func nextDrawing() {
        saveCurrentPage()

        if currentPageIndex < maxPageNum - 1 {
            currentPageIndex += 1
            if let nextDrawingData = pageDraws[currentPageIndex].drawingData, let nextDrawing = try? PKDrawing(data: nextDrawingData) {
                canvasView.drawing = nextDrawing
            }
        }
        updateUI()
    }

    private func updatePrevNextButton() {
        prevButton.isEnabled = true
        nextButton.isEnabled = true

        if currentPageIndex <= 0 {
            prevButton.isEnabled = false
        }
        if currentPageIndex >= maxPageNum - 1 {
            nextButton.isEnabled = false
        }
    }

    private func updateUI() {
        updateCanvasViewBackgroundColor()
        updatePageNumLabel()
        updatePrevNextButton()
        updateCanvas()
    }

    private func updateCanvasViewBackgroundColor() {
        canvasViewBackgroundColor = pageDraws[currentPageIndex].backgroundColor
    }

    private func updatePageNumLabel() {
        pageNumLabel.text = "\(currentPageIndex + 1)/\(maxPageNum)"
    }

    // MARK: PKCanvasViewDelegate

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        print("canvasViewDidBeginUsingTool")
    }

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        print("canvasViewDidEndUsingTool")
        pageDraws[currentPageIndex].isEdited = true
        saveCurrentPage()
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        print("canvasViewDrawingDidChange")
    }

    func canvasViewDidFinishRendering(_ canvasView: PKCanvasView) {
        print("canvasViewDidFinishRendering")
    }

    // MARK: Tool Picker Observer

    func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
        print("toolPickerFramesObscuredDidChange")
    }

    func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        print("toolPickerVisibilityDidChange")
    }
}
